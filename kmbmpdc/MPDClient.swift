import Cocoa
import libmpdclient

extension mpd_idle {
    static func mask(_ masks: mpd_idle...) -> mpd_idle {
        var bitMask: UInt32 = masks[0].rawValue
        for mask in masks[1...] {
            bitMask |= mask.rawValue
        }
        return mpd_idle(bitMask)
    }

    func matches(mask: mpd_idle) -> Bool {
        return self.rawValue & mask.rawValue == mask.rawValue
    }
}

class MPDClient: NSObject {
    static let shared = MPDClient()
    static let idleMask: mpd_idle = mpd_idle.mask(MPD_IDLE_STORED_PLAYLIST, MPD_IDLE_QUEUE,
                                                  MPD_IDLE_PLAYER, MPD_IDLE_OPTIONS)

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

    private var commandQueue: [MPDCommand] = []
    private var mpdConnection: OpaquePointer?
    private var mpdSocket: FileHandle?

    typealias MPDSettingToggle = (OpaquePointer, Bool) -> Bool
    typealias MPDCommand = (OpaquePointer) -> Void

    /// Returns the saved connection host string. If no string is saved in preferences, an empty
    /// string is returned, which in turns makes mpd_connection_new use the default host.
    var connectionHost: String {
        guard let host = UserDefaults.standard.string(forKey: Constants.Preferences.mpdHost) else {
            return ""
        }
        return host
    }

    /// Returns the saved connection password string. If no string is saved in preferences, nil is returned.
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

    /// Adds an array of `Track` objects at the end of the queue.
    func append(_ tracks: [Track]) {
        runBlock { connection in
            for track in tracks {
                mpd_run_add(connection, track.uri)
            }
        }
    }

    /// Checks that the controller has some kind of permission to message the server. Returns `true`
    /// if `MPDClient` can access enough  server commands.
    ///
    /// The permissions that `MPDClient` looks for are _"play"_ (for control) and _"currentsong"_
    /// (for reading the server).
    private func checkPermissions() -> Bool {
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
            mpd_send_idle_mask(self.mpdConnection!, MPDClient.idleMask)

            mpdSocket = FileHandle(fileDescriptor: mpd_connection_get_fd(mpdConnection!))
            mpdSocket?.readabilityHandler = self.handleIdleEvent

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
    func disconnect() {
        mpd_connection_free(mpdConnection!)
        mpdSocket = nil
        connected = false

        let notification = Notification(name: Constants.Notifications.disconnected, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Checks and attempts to recover from errors. If error cannot be recovered from, disconnects client.
    @discardableResult private func handleError() -> Bool {
        if mpd_connection_get_error(mpdConnection!) != MPD_ERROR_SUCCESS {
            let result = mpd_connection_clear_error(mpdConnection!)
            if !result {
                disconnect()
            }
            return result
        }
        return true
    }

    /// Fired every time the MPD socket is ready to be read. Handles updating the player state with
    /// the information from the server as well as sending commands sent with runBlock.
    private func handleIdleEvent(socket: FileHandle) {
        let event_mask: mpd_idle = mpd_recv_idle(mpdConnection!, true)
        self.handleError()

        if event_mask.matches(mask: MPD_IDLE_STORED_PLAYLIST) {
            reloadPlaylists()
        }
        if event_mask.matches(mask: MPD_IDLE_PLAYER) {
            reloadPlayerStatus()
        }
        if event_mask.matches(mask: MPD_IDLE_QUEUE) {
            reloadQueue()
        }
        if event_mask.matches(mask: MPD_IDLE_OPTIONS) {
            reloadOptions()
        }

        while commandQueue.count > 0 {
            let command = commandQueue.removeFirst()
            command(mpdConnection!)
        }

        mpd_send_idle_mask(mpdConnection!, MPDClient.idleMask)
    }

    /// Inserts given tracks at the given position.
    func insert(_ connection: OpaquePointer, tracks: [Track], at beginning: UInt32) {
        var position = beginning
        for track in tracks {
            mpd_run_add_id_to(connection, track.uri, position)
            position += 1
        }
    }

    /// Inserts given tracks before the first track with a different album name compared to the
    /// current track album name.
    func insertAfterCurrentAlbum(_ tracks: [Track]) {
        runBlock { connection in
            let status = mpd_run_status(connection)
            var position = UInt32(mpd_status_get_song_pos(status) + 1)
            if let albumName = self.currentTrack?.album {
                let queueLength = mpd_status_get_queue_length(status)
                while position < queueLength {
                    let song = mpd_run_get_queue_song_pos(connection, position)
                    if song == nil {
                        break
                    }
                    let track = Track(trackInfo: song!)

                    if track.album == albumName {
                        position += 1
                    } else {
                        break
                    }
                }
            }
            self.insert(connection, tracks: tracks, at: position)
            mpd_status_free(status)
        }
    }

    /// Inserts given tracks after currently playing song.
    func insertAfterCurrentTrack(_ tracks: [Track]) {
        runBlock { connection in
            let status = mpd_run_status(connection)
            let position = UInt32(mpd_status_get_song_pos(status) + 1)
            self.insert(connection, tracks: tracks, at: position)
            mpd_status_free(status)
        }
    }

    /// Inserts given tracks to the beginning of the queue.
    func insertAtBeginning(_ tracks: [Track]) {
        runBlock { connection in
            self.insert(connection, tracks: tracks, at: 0)
        }
    }

    /// Loads playlist with given name and starts playback at first item based on queue length.
    func loadPlaylist(_ name: String) {
        runBlock { connection in
            let status = mpd_run_status(connection)
            let queueLength = mpd_status_get_queue_length(status)
            mpd_status_free(status)
            mpd_run_load(connection, name)
            mpd_run_play_pos(connection, queueLength)
        }
    }

    /// Get song ID from MPD server by queue identifier.
    func lookupSong(identifier: Int32) -> OpaquePointer {
        return mpd_run_get_queue_song_id(mpdConnection!, UInt32(identifier))
    }

    /// Moves given track after the currently playing track.
    func moveAfterCurrent(_ track: Track) {
        runBlock { connection in
            let status = mpd_run_status(connection)
            let position: UInt32 = UInt32(mpd_status_get_song_pos(status) + 1)
            mpd_status_free(status)
            mpd_run_move_id(connection, UInt32(track.identifier), position)
        }
    }

    /// Goes to the next track on the current playlist.
    func next() {
        runBlock { connection in
            mpd_run_next(connection)
        }
    }

    /// Toggles between play and pause modes. If there isn't a song currently playing or paused, starts playing the
    /// first track on the playlist to make sure there is a change to playback when requested.
    func playPause() {
        runBlock { connection in
            let status = mpd_run_status(connection)
            switch mpd_status_get_state(status) {
            case MPD_STATE_PLAY:
                mpd_run_pause(connection, true)
            case MPD_STATE_PAUSE:
                mpd_run_play(connection)
            default:
                mpd_send_list_queue_range_meta(connection, 0, 1)
                if let song = mpd_recv_song(connection) {
                    mpd_run_play_pos(connection, 0)
                    mpd_song_free(song)
                }
            }
            mpd_status_free(status)
        }
    }

    /// Goes to the previous track on the current playlist.
    func previous() {
        runBlock { connection in
            mpd_run_previous(connection)
        }
    }

    /// Toggles random mode.
    func randomModeToggle() {
        toggleMode(randomMode, modeToggleFunction: mpd_run_random)
    }

    /// Checks MPD playing state and looks for potential track changes for notifications. Sends a
    /// KMBMPDCPlayerReload notification upon completion.
    private func reloadPlayerStatus() {
        var changedTrack: Bool = false
        let status = mpd_run_status(mpdConnection!)
        let songId: Int32 = mpd_status_get_song_id(status)
        let performQueueReload: Bool = songId != currentTrack?.identifier
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

        if performQueueReload {
            reloadQueue()
        }

        let notification = Notification(name: Constants.Notifications.playerRefresh, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Fetches the current playlists and adds the playlist names to `playlists` array.
    /// Sends a KMBMPDCPlaylistReload notification when the operation is finished.
    private func reloadPlaylists() {
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
    private func reloadOptions() {
        let status = mpd_run_status(mpdConnection!)
        consumeMode = mpd_status_get_consume(status)
        repeatMode = mpd_status_get_repeat(status)
        randomMode = mpd_status_get_random(status)
        singleMode = mpd_status_get_single(status)
        mpd_status_free(status)

        let notification = Notification(name: Constants.Notifications.optionsRefresh, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Fetches the queue not including the currently playing track and saves it to the global `TrackQueue` object.
    private func reloadQueue() {
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

        let notification = Notification(name: Constants.Notifications.queueRefresh, object: nil)
        NotificationCenter.default.post(notification)
    }

    /// Removes a track from the queue.
    func remove(_ track: Track) {
        runBlock { connection in
            mpd_run_delete_id(connection, UInt32(track.identifier))
        }
    }

    /// Toggles repeat mode.
    func repeatModeToggle() {
        toggleMode(repeatMode, modeToggleFunction: mpd_run_repeat)
    }

    /// Run MPD commands. Breaks idle loop in order for the commands to be processed.
    /// - Parameter block: Commands to run after idle loop exits.
    private func runBlock(block: @escaping MPDCommand) {
        commandQueue.append(block)
        mpd_send_noidle(mpdConnection!)
    }

    /// Performs search in MPD. Doesn't use any constraints in the search.
    /// - Parameter searchString: String to perform the search with.
    /// - Parameter update: Called with the Track array when search is complete.
    func search(for searchString: String, update: @escaping ([Track]) -> Void) {
        runBlock { connection in
            var tracks: [Track] = []
            mpd_search_db_songs(connection, false)
            mpd_search_add_any_tag_constraint(connection, MPD_OPERATOR_DEFAULT, searchString)
            let success = mpd_search_commit(connection)
            while success {
                let song = mpd_recv_song(connection)
                if song == nil {
                    break
                }
                let track = Track(trackInfo: song!)
                tracks.append(track)
            }
            update(tracks)
        }
    }

    /// Toggles single mode.
    func singleModeToggle() {
        toggleMode(singleMode, modeToggleFunction: mpd_run_single)
    }

    /// Stops playback.
    func stop() {
        runBlock { connection in
            mpd_run_stop(connection)
        }
    }

    /// Toggles a MPD option with idle mode cancel and resume, and refreshes the instance variables from MPD afterwards.
    /// - Parameter mode: MPDClient instance variable that stores the option value.
    /// - Parameter modeToggleFunction: libmpdclient function that toggles the option.
    private func toggleMode(_ mode: Bool, modeToggleFunction: @escaping MPDSettingToggle) {
        runBlock { connection in
            _ = modeToggleFunction(connection, !mode)
            self.reloadOptions()
        }
    }
}
