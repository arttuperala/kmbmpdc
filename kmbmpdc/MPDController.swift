import Cocoa
import libmpdclient

class MPDController: NSObject {
    static let sharedController = MPDController()
    static let idleMask: mpd_idle = mpd_idle(MPD_IDLE_PLAYER.rawValue | MPD_IDLE_OPTIONS.rawValue)

    var mpdConnection: OpaquePointer?

    var connected: Bool = false
    var consumeMode: Bool = false
    var currentTrack: Track?
    var idling: Bool = false
    var playerState: mpd_state = MPD_STATE_UNKNOWN
    var quitIdle: Bool = false
    var randomMode: Bool = false
    var repeatMode: Bool = false
    var singleMode: Bool = false
    var stopAfterCurrent: Bool = false

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

    /// Returns a `Bool` indicating whether or not the user has user notifications enabled.
    var notificationsEnabled: Bool {
        return !UserDefaults.standard.bool(forKey: Constants.Preferences.notificationsDisabled)
    }

    /// Checks that the controller has some kind of permission to message the server. Returns `true`
    /// if MPDController can access enough  server commands.
    ///
    /// The permissions that MPDController looks for are _"play"_ (for control) and _"currentsong"_
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
            reloadPlayerStatus(false)
            reloadOptions()
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

    func getIdleEvent(event: mpd_idle) -> MPDIdleEvent {
        if event.rawValue & MPD_IDLE_PLAYER.rawValue == MPD_IDLE_PLAYER.rawValue {
            return MPDIdleEvent.player
        } else if event.rawValue & MPD_IDLE_OPTIONS.rawValue == MPD_IDLE_OPTIONS.rawValue {
            return MPDIdleEvent.options
        } else {
            return MPDIdleEvent.none
        }
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

    func lookupSong(identifier: Int32) -> OpaquePointer {
        return mpd_run_get_queue_song_id(mpdConnection!, UInt32(identifier))
    }

    /// Goes to the next track on the current playlist.
    func next() {
        idleExit()
        mpd_run_next(mpdConnection!)
        idleEnter()
    }

    /// Sends a notification with the current track name, artist and album.
    func notifyTrackChange() {
        let notification = NSUserNotification()
        notification.identifier = Constants.UserNotifications.trackChange
        notification.title = currentTrack?.name
        notification.subtitle = currentTrack?.artist
        notification.informativeText = currentTrack?.album
        notification.contentImage = currentTrack?.coverArt

        let center = NSUserNotificationCenter.default
        for deliveredNotification in center.deliveredNotifications {
            if deliveredNotification.identifier == Constants.UserNotifications.trackChange {
                center.removeDeliveredNotification(deliveredNotification)
            }
        }
        center.deliver(notification)
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
                self.idling = mpd_send_idle_mask(self.mpdConnection!, MPDController.idleMask)
                let event_mask: mpd_idle = mpd_recv_idle(self.mpdConnection!, true)
                switch self.getIdleEvent(event: event_mask) {
                case .player:
                    self.reloadPlayerStatus()
                case .options:
                    self.reloadOptions()
                case .none:
                    if !self.quitIdle {
                        self.disconnect(false)
                        break idleLoop
                    }
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
    /// - Parameter showNotification: Boolean indicating if a track change notification should be
    /// sent out if noticed. Defaults to true.
    func reloadPlayerStatus(_ showNotification: Bool = true) {
        var changedTrack: Bool = false
        var displayNotification: Bool = showNotification && notificationsEnabled

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

        if stopAfterCurrent && changedTrack {
            mpd_run_stop(mpdConnection!)
            stopAfterCurrent = false
            displayNotification = false
        }

        if displayNotification && changedTrack {
            DispatchQueue.main.async {
                self.notifyTrackChange()
            }
        }

        let notification = Notification(name: Constants.Notifications.playerRefresh, object: nil)
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
    /// - Parameter mode: MPDController instance variable that stores the option value.
    /// - Parameter modeToggleFunction: libmpdclient function that toggles the option.
    func toggleMode(_ mode: Bool, modeToggleFunction: MPDSettingToggle) {
        idleExit()
        _ = modeToggleFunction(mpdConnection!, !mode)
        reloadOptions()
        idleEnter()
    }
}

enum MPDIdleEvent: Int {
    case none = 0
    case player
    case options
}
