import Cocoa
import libmpdclient

class MPDClient: NSObject {
    static let shared = MPDClient()
    static let idleMask: mpd_idle = mpd_idle(MPD_IDLE_STORED_PLAYLIST.rawValue |
                                             MPD_IDLE_QUEUE.rawValue |
                                             MPD_IDLE_PLAYER.rawValue |
                                             MPD_IDLE_OPTIONS.rawValue)

    var mpdConnection: OpaquePointer?

    var connected: Bool = false
    var consumeMode: Bool = false
    var currentTrack: Track?
    var idling: Bool = false
    var playerState: mpd_state = MPD_STATE_UNKNOWN
    var playlists: [String] = []
    var quitIdle: Bool = false
    var randomMode: Bool = false
    var repeatMode: Bool = false
    var singleMode: Bool = false
    var stopAfterCurrent: Bool = false

    private var queueBusy: Bool = false

    typealias MPDSettingToggle = (OpaquePointer, Bool) -> Bool

    /// Returns the saved connection host string. If no string is saved in preferences, an empty
    /// string is returned, which in turns makes mpd_connection_new use the default host.
    var connectionHost: String {
        guard let host = UserDefaults.standard.string(forKey: Constants.Preferences.mpdHost) else {
            return ""
        }
        return host
    }

    /// Returns the saved connection password string. If no string is saved in preferences, nil is
    /// returned.
    var connectionPassword: String? {
        guard let pass = UserDefaults.standard.string(forKey: Constants.Preferences.mpdPass) else {
            return nil
        }
        return pass
    }

    /// Returns the saved connection port. If no port is saved in preferences, 0 is returned, which
    /// in turn makes mpd_connection_new use the default port.
    var connectionPort: UInt32 {
        return UInt32(UserDefaults.standard.integer(forKey: Constants.Preferences.mpdPort))
    }

    /// Checks that the controller has some kind of permission to message the server. Returns `true`
    /// if `MPDClient` can access enough  server commands.
    ///
    /// The permissions that `MPDClient` looks for are _"play"_ (for control) and _"currentsong"_
    /// (for reading the server).
    func checkPermissions() -> Bool {
        var currentSongPermission = false
        var playPermission = false

        mpd_send_allowed_commands(mpdConnection!)
        while true {
            let commandPair = mpd_recv_pair(mpdConnection!)
            if commandPair == nil {
                break
            }
            switch String(cString: (commandPair?.pointee.value)!) {
            case "currentsong":
                currentSongPermission = true
            case "play":
                playPermission = true
            default:
                break
            }
            mpd_return_pair(mpdConnection!, commandPair)
        }
        return currentSongPermission && playPermission
    }

    /// Attemps connection to the MPD server and sets connected to true if connection is successful.
    func connect() {
        mpdConnection = mpd_connection_new(connectionHost, connectionPort, 0)
        let connectionError = mpd_connection_get_error(mpdConnection!)
        var notificationName: NSNotification.Name = Constants.Notifications.disconnected
        initializeConnection: if connectionError == MPD_ERROR_SUCCESS {
            if connectionPassword != nil {
                mpd_run_password(mpdConnection!, connectionPassword)
            }
            if !checkPermissions() {
                break initializeConnection
            }

            connected = true
            mpd_connection_set_keepalive(mpdConnection!, true)
            reloadPlayerStatus()
            reloadOptions()
            reloadPlaylists()
            reloadQueue()
            idleEnter()

            notificationName = Constants.Notifications.connected
        }

        NotificationCenter.default.post(Notification(name: notificationName, object: nil))
    }

    /// Toggles consume mode.
    func consumeModeToggle() {
        toggleMode(consumeMode, modeToggleFunction: mpd_run_consume)
    }

    /// Frees up the connection and sets the instance variable connected to false. Also exits idle
    /// if still idling. Sends a KMBMPDCDisconnected on completion.
    /// - Parameter exitIdle: Boolean value indicating if idle should be exited before the
    /// connection is freed up. Defaults to true.
    func disconnect(_ exitIdle: Bool = true) {
        if exitIdle {
            idleExit()
        }
        mpd_connection_free(mpdConnection!)
        connected = false

        let notification = Notification(name: Constants.Notifications.disconnected, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Starts the idling background loop and sets quitIdle to false.
    func idleEnter() {
        quitIdle = false
        receiveIdleEvents()
    }

    /// Sets quitIdle variable to false, prompting the background idle loop to exit. Blocks until
    /// the idle loop exits.
    func idleExit() {
        quitIdle = true
        mpd_send_noidle(mpdConnection!)
        while self.idling {
            usleep(100 * 1000)
        }
    }

    /// Loads playlist with given name and starts playback at first item based on queue length.
    func loadPlaylist(_ name: String) {
        idleExit()
        let status = mpd_run_status(mpdConnection!)
        let queueLength = mpd_status_get_queue_length(status)
        mpd_status_free(status)
        mpd_run_load(mpdConnection!, name)
        mpd_run_play_pos(mpdConnection!, queueLength)
        idleEnter()
    }

    func lookupSong(identifier: Int32) -> OpaquePointer {
        return mpd_run_get_queue_song_id(mpdConnection!, UInt32(identifier))
    }

    func matchIdle(event: mpd_idle, mask: mpd_idle) -> Bool {
        return event.rawValue & mask.rawValue == mask.rawValue
    }

    /// Goes to the next track on the current playlist.
    func next() {
        idleExit()
        mpd_run_next(mpdConnection!)
        idleEnter()
    }

    /// Toggles between play and pause modes. If there isn't a song currently playing or paused,
    /// starts playing the first track on the playlist to make sure there is a change to playback
    /// when requested.
    func playPause() {
        idleExit()
        let status = mpd_run_status(mpdConnection!)
        switch mpd_status_get_state(status) {
        case MPD_STATE_PLAY:
            mpd_run_pause(mpdConnection, true)
        case MPD_STATE_PAUSE:
            mpd_run_play(mpdConnection!)
        default:
            mpd_send_list_queue_range_meta(mpdConnection!, 0, 1)
            if let song = mpd_recv_song(mpdConnection!) {
                mpd_run_play_pos(mpdConnection!, 0)
                mpd_song_free(song)
            }
        }
        mpd_status_free(status)
        idleEnter()
    }

    /// Goes to the previous track on the current playlist.
    func previous() {
        idleExit()
        mpd_run_previous(mpdConnection!)
        idleEnter()
    }

    /// Continuously sends idle commands to MPD until quitIdle is set to true. When the loop exits,
    /// idling property is set to false so that operations that wait for idling to be finished can
    /// continue execution.
    func receiveIdleEvents() {
        DispatchQueue.global(qos: .background).async {
            idleLoop: while !self.quitIdle {
                self.idling = mpd_send_idle_mask(self.mpdConnection!, MPDClient.idleMask)
                let event_mask: mpd_idle = mpd_recv_idle(self.mpdConnection!, true)

                // Received no data; disconnect if not peacefully exiting idle.
                if event_mask.rawValue == 0 {
                    if !self.quitIdle {
                        self.disconnect(false)
                        break idleLoop
                    }
                }

                if self.matchIdle(event: event_mask, mask: MPD_IDLE_STORED_PLAYLIST) {
                    self.reloadPlaylists()
                }
                if self.matchIdle(event: event_mask, mask: MPD_IDLE_PLAYER) {
                    self.reloadPlayerStatus()
                }
                if self.matchIdle(event: event_mask, mask: MPD_IDLE_QUEUE) {
                    self.reloadQueue()
                }
                if self.matchIdle(event: event_mask, mask: MPD_IDLE_OPTIONS) {
                    self.reloadOptions()
                }
            }
            self.idling = false
        }
    }

    /// Toggles random mode.
    func randomModeToggle() {
        toggleMode(randomMode, modeToggleFunction: mpd_run_random)
    }

    /// Checks MPD playing state and looks for potential track changes for notifications. Sends a
    /// KMBMPDCPlayerReload notification upon completion.
    func reloadPlayerStatus() {
        var changedTrack: Bool = false
        let status = mpd_run_status(mpdConnection!)
        let songId: Int32 = mpd_status_get_song_id(status)
        playerState = mpd_status_get_state(status)
        mpd_status_free(status)

        // If the player state stopped or unknown, or mpd returns -1 as current track ID, the track
        // is set to nil. Else if the song ID differs from the stored song ID, currentTrack is
        // replaced and boolean flag `changedTrack` is set `true`.
        if playerState.rawValue < 2 || songId < 0 {
            currentTrack = nil
        } else if songId != currentTrack?.identifier {
            currentTrack = Track(identifier: songId)
            changedTrack = true
        }

        reloadQueue()

        if stopAfterCurrent && changedTrack {
            let stopped = mpd_run_stop(mpdConnection!)
            if stopped {
                currentTrack = nil
                stopAfterCurrent = false
            }
        }

        if changedTrack {
            let notification = Notification(name: Constants.Notifications.changedTrack, object: nil)
            NotificationCenter.default.post(notification)
        }

        let notification = Notification(name: Constants.Notifications.playerRefresh, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Fetches the current playlists and adds the playlist names to `playlists` array.
    /// Sends a KMBMPDCPlaylistReload notification when the operation is finished.
    func reloadPlaylists() {
        let success: Bool = mpd_send_list_playlists(mpdConnection!)
        guard success else {
            return
        }
        playlists.removeAll()
        while true {
            let playlist = mpd_recv_playlist(mpdConnection!)
            if playlist == nil {
                break
            }
            let path = String(cString: mpd_playlist_get_path(playlist))
            playlists.append(path)
            mpd_playlist_free(playlist)
        }

        let notification = Notification(name: Constants.Notifications.playlistRefresh, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Fetches the current options of MPD and updates the instance variables with the new data.
    /// Sends a KMBMPDCOptionsReload notification when the operation is finished.
    func reloadOptions() {
        let status = mpd_run_status(mpdConnection!)
        consumeMode = mpd_status_get_consume(status)
        repeatMode = mpd_status_get_repeat(status)
        randomMode = mpd_status_get_random(status)
        singleMode = mpd_status_get_single(status)
        mpd_status_free(status)

        let notification = Notification(name: Constants.Notifications.optionsRefresh, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Fetches the queue not including the currently playing track and saves it to the global
    /// `TrackQueue` object.
    func reloadQueue() {
        while self.queueBusy {
            usleep(100 * 1000)
        }
        self.queueBusy = true

        let success = mpd_send_list_queue_meta(mpdConnection!)
        var newQueue: [Track] = []
        while success {
            guard let song = mpd_recv_song(mpdConnection!) else {
                break
            }
            let track = Track(trackInfo: song)
            newQueue.append(track)
        }

        // Crop the queue to ensure it only contains upcoming tracks using the current track
        // position or 0, whichever is larger.
        if currentTrack != nil {
            let status = mpd_run_status(mpdConnection!)
            let currentTrackPosition: Int32 = mpd_status_get_song_pos(status)
            mpd_status_free(status)
            newQueue.removeSubrange(0...Int(currentTrackPosition))
        }

        TrackQueue.global.tracks = newQueue
        self.queueBusy = false

        let notification = Notification(name: Constants.Notifications.queueRefresh, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Toggles repeat mode.
    func repeatModeToggle() {
        toggleMode(repeatMode, modeToggleFunction: mpd_run_repeat)
    }

    /// Toggles single mode.
    func singleModeToggle() {
        toggleMode(singleMode, modeToggleFunction: mpd_run_single)
    }

    /// Stops playback.
    func stop() {
        idleExit()
        mpd_run_stop(mpdConnection!)
        idleEnter()
    }

    /// Toggles a MPD option with idle mode cancel and resume, and refreshes the instance variables
    /// from MPD afterwards.
    /// - Parameter mode: MPDClient instance variable that stores the option value.
    /// - Parameter modeToggleFunction: libmpdclient function that toggles the option.
    func toggleMode(_ mode: Bool, modeToggleFunction: MPDSettingToggle) {
        idleExit()
        _ = modeToggleFunction(mpdConnection!, !mode)
        reloadOptions()
        idleEnter()
    }
}
