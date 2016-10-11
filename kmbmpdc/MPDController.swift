import Cocoa
import libmpdclient

class MPDController: NSObject {
    static let sharedController = MPDController()
    static var idleMask: mpd_idle = mpd_idle(rawValue: MPD_IDLE_PLAYER.rawValue |
                                                        MPD_IDLE_OPTIONS.rawValue)
    var mpdConnection: OpaquePointer?

    var connected: Bool = false
    var consumeMode: Bool = false
    var currentTrack: Int32 = -1
    var idling: Bool = false
    var playerState: mpd_state = MPD_STATE_UNKNOWN
    var quitIdle: Bool = false
    var randomMode: Bool = false
    var repeatMode: Bool = false
    var singleMode: Bool = false

    /// Attemps connection to the MPD server and sets connected to true if connection is successful.
    func connect() {
        mpdConnection = mpd_connection_new("127.0.0.1", 0, 0)
        mpd_connection_set_keepalive(mpdConnection!, true)
        let connectionError = mpd_connection_get_error(mpdConnection!)
        if connectionError == MPD_ERROR_SUCCESS {
            connected = true
            reloadPlayerStatus(false)
            reloadOptions()
            idleEnter()

            let notification = Notification(name: Notification.Name(rawValue: Constants.Notifications.connected), object: nil)
            NotificationCenter.default.post(notification)
        }
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

        let notification = Notification(name: Notification.Name(rawValue: Constants.Notifications.disconnected), object: nil)
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
            usleep(100)
        }
    }

    /// Goes to the next track on the current playlist.
    func next() {
        idleExit()
        mpd_run_next(mpdConnection!)
        idleEnter()
    }

    /// Sends a notification with the current track name, artist and album.
    func notifyTrackChange() {
        let trackInfo = mpd_run_get_queue_song_id(mpdConnection!, UInt32(currentTrack))
        let trackName = String(cString: mpd_song_get_tag(trackInfo, MPD_TAG_TITLE, 0))
        let trackAlbum = String(cString: mpd_song_get_tag(trackInfo, MPD_TAG_ALBUM, 0))
        let trackArtist = String(cString: mpd_song_get_tag(trackInfo, MPD_TAG_ARTIST, 0))
        mpd_song_free(trackInfo)

        let notification = NSUserNotification()
        notification.title = trackName
        if trackAlbum != nil && trackArtist != nil {
            notification.informativeText = "\(trackArtist) - \(trackAlbum)"
        } else if trackAlbum != nil {
            notification.informativeText = "null - \(trackAlbum)"
        } else if trackArtist != nil {
            notification.informativeText = "\(trackArtist) - null"
        }
        NSUserNotificationCenter.default.deliver(notification)
    }

    /// Toggles between play and pause modes.
    func playPause() {
        idleExit()
        mpd_run_toggle_pause(mpdConnection!)
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
        let priority = DispatchQueue.GlobalQueuePriority.default
        DispatchQueue.global(priority: priority).async {
            while !self.quitIdle {
                self.idling = mpd_send_idle_mask(self.mpdConnection!, MPDController.idleMask)
                let event_mask: mpd_idle = mpd_recv_idle(self.mpdConnection!, true)
                if event_mask.rawValue & MPD_IDLE_PLAYER.rawValue == MPD_IDLE_PLAYER.rawValue {
                    self.reloadPlayerStatus()
                } else if event_mask.rawValue & MPD_IDLE_OPTIONS.rawValue ==
                          MPD_IDLE_OPTIONS.rawValue {
                    self.reloadOptions()
                } else if event_mask.rawValue == 0 && !self.quitIdle {
                    self.disconnect(false)
                    break
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
        let status = mpd_run_status(mpdConnection!)
        playerState = mpd_status_get_state(status)
        let songId: Int32 = mpd_status_get_song_id(status)
        mpd_status_free(status)

        if songId != currentTrack && songId > -1 {
            currentTrack = songId
            if showNotification { notifyTrackChange() }
        }

        let notification = Notification(name: Notification.Name(rawValue: Constants.Notifications.playerRefresh), object: nil)
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

        let notification = Notification(name: Notification.Name(rawValue: Constants.Notifications.optionsRefresh), object: nil)
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
    /// - parameter modeToggleFunction: libmpdclient function that toggles the option.
    func toggleMode(_ mode: Bool, modeToggleFunction: (OpaquePointer, Bool) -> Bool) {
        idleExit()
        modeToggleFunction(mpdConnection!, !mode)
        reloadOptions()
        idleEnter()
    }
}
