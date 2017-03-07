import Cocoa
import libmpdclient
import MediaKeyTap

class Controller: NSViewController {
    @IBOutlet weak var currentTrackArtist: NSTextField!
    @IBOutlet weak var currentTrackCover: NSImageView!
    @IBOutlet weak var currentTrackTitle: NSTextField!
    @IBOutlet weak var consumeModeButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var playPauseButton: NSButton!
    @IBOutlet weak var playlistButton: NSButton!
    @IBOutlet weak var previousButton: NSButton!
    @IBOutlet weak var randomModeButton: NSButton!
    @IBOutlet weak var repeatModeButton: NSButton!
    @IBOutlet weak var singleModeButton: NSButton!
    @IBOutlet weak var stopButton: NSButton!
    @IBOutlet weak var stopAfterCurrentButton: NSButton!
    @IBOutlet weak var trackQueueTable: NSTableView!

    @IBOutlet weak var trackQueueTableHeight: NSLayoutConstraint!
    @IBOutlet weak var trackQueueTableBottom: NSLayoutConstraint!

    @IBOutlet var trackQueueObject: TrackQueue!

    weak var appDelegate: AppDelegate?
    var reconnectDisable: Bool = false
    var reconnectTimer: Double = 2.0

    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(Controller.clientConnected),
                                       name: Constants.Notifications.connected, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controller.clientDisconnected),
                                       name: Constants.Notifications.disconnected, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controller.updateModeSelections),
                                       name: Constants.Notifications.optionsRefresh, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controller.updatePlayerStatus),
                                       name: Constants.Notifications.playerRefresh, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controller.updateQueue),
                                       name: Constants.Notifications.queueRefresh, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        trackQueueObject = TrackQueue.global
    }

    /// Perform tasks after client connects to the server.
    func clientConnected() {
        DispatchQueue.main.async {
            self.enableControls(true)
        }
        appDelegate?.statusItem.button?.appearsDisabled = false
    }

    /// Perform tasks after client disconnects from the server.
    func clientDisconnected() {
        DispatchQueue.main.async {
            self.currentTrackArtist.stringValue = ""
            self.currentTrackTitle.stringValue = "kmbmpdc"
            self.setCover(nil)
            self.enableControls(false)
        }

        appDelegate?.statusItem.button?.appearsDisabled = true

        if reconnectDisable {
            reconnectDisable = false
        } else {
            reconnectSchedule()
        }
    }

    /// Changes user interface image assets and tooltips depending on current MPD state.
    func changeImageAssets() {
        var playPauseAltImage: NSImage
        var playPauseImage: NSImage
        var playPauseTooltip: String
        var statusItemImage: NSImage
        if MPDController.sharedController.playerState == MPD_STATE_PLAY {
            playPauseAltImage = Bundle.main.image(forResource: "PauseButtonAlt")!
            playPauseImage = Bundle.main.image(forResource: "PauseButton")!
            playPauseTooltip = "Pause"
            statusItemImage = Bundle.main.image(forResource: "StatusPlaying")!
        } else {
            playPauseAltImage = Bundle.main.image(forResource: "PlayButtonAlt")!
            playPauseImage = Bundle.main.image(forResource: "PlayButton")!
            playPauseTooltip = "Play"
            statusItemImage = Bundle.main.image(forResource: "StatusPaused")!
        }
        playPauseButton.alternateImage = playPauseAltImage
        playPauseButton.image = playPauseImage
        playPauseButton.toolTip = playPauseTooltip
        statusItemImage.isTemplate = true
        appDelegate?.statusItem.image = statusItemImage
    }

    /// Enables or disables the user interface controls that require a connection to the server.
    /// - Parameter enabled: `true` if controls should be enabled.
    func enableControls(_ enabled: Bool) {
        consumeModeButton.isEnabled = enabled
        nextButton.isEnabled = enabled
        playPauseButton.isEnabled = enabled
        playlistButton.isEnabled = enabled
        previousButton.isEnabled = enabled
        randomModeButton.isEnabled = enabled
        repeatModeButton.isEnabled = enabled
        singleModeButton.isEnabled = enabled
        stopButton.isEnabled = enabled
        stopAfterCurrentButton.isEnabled = enabled
    }

    /// Loads a playlist by a `NSMenuItem` title.
    func loadPlaylist(_ sender: NSMenuItem) {
        let playlistName = sender.title
        DispatchQueue.global().async {
            MPDController.sharedController.loadPlaylist(playlistName)
        }
    }

    @IBAction func nextWasClicked(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDController.sharedController.next()
        }
    }

    @IBAction func openSubmenu(_ sender: NSButton) {
        let submenu = NSMenu()
        var connectionToggleTitle: String = "Disconnect"
        if !MPDController.sharedController.connected {
            connectionToggleTitle = "Connect"
        }
        submenu.addItem(withTitle: connectionToggleTitle,
                        action: #selector(Controller.toggleConnection), keyEquivalent: "")
        submenu.addItem(withTitle: "Preferences",
                        action: #selector(AppDelegate.openPreferences), keyEquivalent: "")
        submenu.addItem(withTitle: "Quit",
                        action: #selector(NSApp.terminate), keyEquivalent: "")
        submenu.popUp(positioning: nil, at: sender.frame.origin, in: self.view)
    }

    @IBAction func playPauseWasClicked(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDController.sharedController.playPause()
        }
    }

    @IBAction func playlistWasClicked(_ sender: NSButton) {
        let playlistMenu = NSMenu()
        let selector = #selector(Controller.loadPlaylist(_:))
        for playlist in MPDController.sharedController.playlists {
            let menuItem = NSMenuItem(title: playlist, action: selector, keyEquivalent: "")
            playlistMenu.addItem(menuItem)
        }
        playlistMenu.popUp(positioning: nil, at: sender.frame.origin, in: sender)
    }

    @IBAction func previousWasClicked(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDController.sharedController.previous()
        }
    }

    /// Reconnects to the MPD server. If connection is successful, the reconnection time is reset.
    func reconnect() {
        MPDController.sharedController.connect()
        if MPDController.sharedController.connected {
            reconnectTimer = 2.0
        }
    }

    /// Schedules a `Timer` object for reconnecting to the MPD server, adds it to the main loop and
    /// doubles the wait time until next reconnect attempt (capped at 60 seconds).
    func reconnectSchedule() {
        let timer = Timer(timeInterval: reconnectTimer, target: self,
                          selector: #selector(Controller.reconnect), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .commonModes)

        reconnectTimer *= 2
        if reconnectTimer > 60.0 {
            reconnectTimer = 60.0
        }
    }

    /// Set the main cover art in the interface. If the image is `nil`, placeholder art is used
    /// instead.
    /// - Parameter image: New cover image to display or `nil` to display kmbmpdc placeholder.
    func setCover(_ image: NSImage?) {
        if image == nil {
            currentTrackCover.image = Bundle.main.image(forResource: "PlaceholderCover")!
        } else {
            currentTrackCover.image = image
        }
    }

    @IBAction func stopWasClicked(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDController.sharedController.stop()
        }
    }

    /// Sets the `MPDController` boolean flag to stop after current track to the button's value.
    @IBAction func stopAfterCurrentWasClicked(_ sender: NSButton) {
        MPDController.sharedController.stopAfterCurrent = sender.state > 0 ? true : false
    }

    /// Connects to/disconnects from the server.
    func toggleConnection() {
        if MPDController.sharedController.connected {
            reconnectDisable = true
            MPDController.sharedController.disconnect()
        } else {
            MPDController.sharedController.connect()
        }
    }

    @IBAction func toggleConsumeMode(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDController.sharedController.consumeModeToggle()
        }
    }
    @IBAction func toggleQueue(_ sender: NSButton) {
        // If display is toggled on, `sender.state` equals 1 and if not, 0. When the queue view is
        // toggled on, it's 200 points high and has 4 point bottom margin.
        trackQueueTableBottom.animator().constant = CGFloat(sender.state * 4)
        trackQueueTableHeight.animator().constant = CGFloat(sender.state * 200)
    }

    @IBAction func toggleRandomMode(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDController.sharedController.randomModeToggle()
        }
    }

    @IBAction func toggleRepeatMode(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDController.sharedController.repeatModeToggle()
        }
    }

    @IBAction func toggleSingleMode(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDController.sharedController.singleModeToggle()
        }
    }

    /// Listens to KMBMPDCOptionsReload notifications and updates the main menu
    /// items with the correct values from MPDController.
    func updateModeSelections() {
        consumeModeButton.state = MPDController.sharedController.consumeMode ? 1 : 0
        randomModeButton.state = MPDController.sharedController.randomMode ? 1 : 0
        repeatModeButton.state = MPDController.sharedController.repeatMode ? 1 : 0
        singleModeButton.state = MPDController.sharedController.singleMode ? 1 : 0
    }

    /// Updates user interface when MPD state or current track changes.
    func updatePlayerStatus() {
        var trackArtist: String = ""
        var trackCover: NSImage? = nil
        var trackTitle: String = "kmbmpdc"
        if let currentTrack = MPDController.sharedController.currentTrack {
            trackArtist = currentTrack.artist
            trackCover = currentTrack.coverArt
            trackTitle = currentTrack.name
        }

        DispatchQueue.main.async {
            self.changeImageAssets()
            self.currentTrackArtist.stringValue = trackArtist
            self.currentTrackTitle.stringValue = trackTitle
            self.setCover(trackCover)
            self.stopAfterCurrentButton.state = MPDController.sharedController.stopAfterCurrent ? 1 : 0
        }
    }

    /// Updates the track queue table when the global `TrackQueue` is updated.
    func updateQueue() {
        DispatchQueue.main.async {
            self.trackQueueTable.reloadData()
        }
    }

}
