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
    @IBOutlet weak var trackQueueButton: NSButton!
    @IBOutlet weak var trackQueueSeparator: NSBox!
    @IBOutlet weak var trackQueueTable: NSTableView!

    @IBOutlet weak var currentTrackCoverHeight: NSLayoutConstraint!
    @IBOutlet weak var trackQueueTableHeight: NSLayoutConstraint!

    weak var appDelegate: AppDelegate?
    var searchPopover: NSPopover?
    var reconnectDisable: Bool = false
    var reconnectTimer: Double = 2.0

    /// Returns a `Bool` indicating whether or not the user has user notifications enabled.
    var notificationsEnabled: Bool {
        return !UserDefaults.standard.bool(forKey: Constants.Preferences.notificationsDisabled)
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(Controller.clientConnected),
                                       name: Constants.Notifications.connected, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controller.clientDisconnected),
                                       name: Constants.Notifications.disconnected, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controller.notifyTrackChange),
                                       name: Constants.Notifications.changedTrack, object: nil)
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
        trackQueueTable.dataSource = TrackQueue.global
        trackQueueTable.delegate = TrackQueue.global
        toggleQueue(trackQueueButton)
    }

    override func cancelOperation(_ sender: Any?) {
        appDelegate?.closePopover()
    }

    /// Perform tasks after client connects to the server.
    @objc func clientConnected() {
        DispatchQueue.main.async {
            self.enableControls(true)
        }
        appDelegate?.statusItem.button?.appearsDisabled = false
    }

    /// Perform tasks after client disconnects from the server.
    @objc func clientDisconnected() {
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
        if MPDClient.shared.playerState == MPD_STATE_PLAY {
            playPauseAltImage = Bundle.main.image(forResource: Constants.Images.pauseButtonAlt)!
            playPauseImage = Bundle.main.image(forResource: Constants.Images.pauseButton)!
            playPauseTooltip = "Pause"
            statusItemImage = Bundle.main.image(forResource: Constants.Images.statusPlaying)!
        } else {
            playPauseAltImage = Bundle.main.image(forResource: Constants.Images.playButtonAlt)!
            playPauseImage = Bundle.main.image(forResource: Constants.Images.playButton)!
            playPauseTooltip = "Play"
            statusItemImage = Bundle.main.image(forResource: Constants.Images.statusPaused)!
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
    @objc func loadPlaylist(_ sender: NSMenuItem) {
        let playlistName = sender.title
        DispatchQueue.global().async {
            MPDClient.shared.loadPlaylist(playlistName)
        }
    }

    @IBAction func nextWasClicked(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDClient.shared.next()
        }
    }

    /// Sends a notification with the current track name, artist, album and cover art.
    @objc func notifyTrackChange() {
        guard notificationsEnabled, let track = MPDClient.shared.currentTrack else {
            return
        }

        let notification = NSUserNotification()
        notification.identifier = Constants.UserNotifications.trackChange
        notification.title = track.name
        notification.subtitle = track.artist
        notification.informativeText = track.album
        notification.contentImage = track.coverArt

        DispatchQueue.main.async {
            let center = NSUserNotificationCenter.default
            for deliveredNotification in center.deliveredNotifications {
                if deliveredNotification.identifier == Constants.UserNotifications.trackChange {
                    center.removeDeliveredNotification(deliveredNotification)
                }
            }
            center.deliver(notification)
        }
    }

    @IBAction func openSearch(_ sender: NSButton) {
        if searchPopover == nil {
            let searchView = Search(nibName: Constants.Nibs.search, bundle: Bundle.main)
            searchPopover = NSPopover()
            searchPopover!.contentViewController = searchView
            searchPopover!.behavior = .transient
            searchPopover!.appearance = NSAppearance(named: NSAppearance.Name.aqua)
        }
        searchPopover!.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxX)
    }

    @IBAction func openSubmenu(_ sender: NSButton) {
        let submenu = NSMenu()
        var connectionToggleTitle: String = "Disconnect"
        if !MPDClient.shared.connected {
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
            MPDClient.shared.playPause()
        }
    }

    @IBAction func playlistWasClicked(_ sender: NSButton) {
        let playlistMenu = NSMenu()
        let selector = #selector(Controller.loadPlaylist(_:))
        for playlist in MPDClient.shared.playlists {
            let menuItem = NSMenuItem(title: playlist, action: selector, keyEquivalent: "")
            playlistMenu.addItem(menuItem)
        }
        // Under the playlist button
        let point = NSPoint(x: 0, y: sender.frame.height)
        playlistMenu.popUp(positioning: nil, at: point, in: sender)
    }

    @IBAction func previousWasClicked(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDClient.shared.previous()
        }
    }

    @IBAction func queuePlayNext(_ sender: NSMenuItem) {
        if let track = TrackQueue.global.get(trackQueueTable.clickedRow) {
            MPDClient.shared.moveAfterCurrent(track)
        }
    }

    @IBAction func queueRemove(_ sender: NSMenuItem) {
        if let track = TrackQueue.global.get(trackQueueTable.clickedRow) {
            MPDClient.shared.remove(track)
        }
    }

    /// Reconnects to the MPD server. If connection is successful, the reconnection time is reset.
    @objc func reconnect() {
        MPDClient.shared.connect()
        if MPDClient.shared.connected {
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
    /// instead. The `NSImageView` displaying the cover art is then resized to fit the aspect ratio
    /// of the image, with 89 points being the minimum value and 600 points being the maximum value.
    /// - Parameter image: New cover image to display or `nil` to display kmbmpdc placeholder.
    func setCover(_ cover: NSImage?) {
        var source: NSImage
        if cover == nil {
            source = Bundle.main.image(forResource: Constants.Images.placeholderCover)!
        } else {
            source = cover!
        }

        // Produce a scaled version of the given cover art to fit the target `NSImageView`.
        // `NSImage` is produced by creating two different sized bitmap representations, one 300
        // pixels wide and other 600 pixels wide, in order to display good quality cover art on
        // regular PPI displays and Apple's Retina displays.
        // `NSImageInterpolation.high` is used to produce better quality scaling, especially when
        // downscaling bigger cover art scans.
        let height = floor(source.size.height / source.size.width * 300.0)
        let image = NSImage(size: NSSize(width: 300.0, height: height))
        for i: CGFloat in [1, 2] {
            let pixelsWide: Int = 300 * Int(i)
            let pixelsHigh: Int = Int(height * i)
            if let bitmapRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                                pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
                                                bitsPerSample: 8, samplesPerPixel: 4,
                                                hasAlpha: true, isPlanar: false,
                                                colorSpaceName: NSColorSpaceName.calibratedRGB,
                                                bytesPerRow: 0, bitsPerPixel: 0) {
                let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
                let inRect = NSRect(x: 0.0, y: 0.0, width: 300.0 * i, height: height * i)

                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                NSGraphicsContext.current?.imageInterpolation = NSImageInterpolation.high
                source.draw(in: inRect, from: NSRect.zero, operation: .sourceOver, fraction: 1.0)
                NSGraphicsContext.restoreGraphicsState()
                image.addRepresentation(bitmapRep)
            }
        }

        let coverHeight = min(max(image.size.height, 89), 600)
        currentTrackCover.image = image
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.25
        currentTrackCoverHeight.animator().constant = coverHeight
        NSAnimationContext.endGrouping()
    }

    @IBAction func stopWasClicked(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDClient.shared.stop()
        }
    }

    /// Sets the `MPDClient` boolean flag to stop after current track to the button's value.
    @IBAction func stopAfterCurrentWasClicked(_ sender: NSButton) {
        MPDClient.shared.stopAfterCurrent = sender.state == .on
    }

    /// Connects to/disconnects from the server.
    @objc func toggleConnection() {
        if MPDClient.shared.connected {
            reconnectDisable = true
            MPDClient.shared.disconnect()
        } else {
            MPDClient.shared.connect()
        }
    }

    @IBAction func toggleConsumeMode(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDClient.shared.consumeModeToggle()
        }
    }
    @IBAction func toggleQueue(_ sender: NSButton) {
        // If display is toggled on, `sender.state` equals 1 and if not, 0. When the queue view is
        // toggled on, it's 201 points high and the separator horizontal line is displayed.
        trackQueueSeparator.isHidden = false
        NSAnimationContext.runAnimationGroup({ _ in
            trackQueueTableHeight.animator().constant = sender.state == .on ? 201 : 0
        }) {
            if sender.state == .off {
                self.trackQueueSeparator.isHidden = true
            }
        }
    }

    @IBAction func toggleRandomMode(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDClient.shared.randomModeToggle()
        }
    }

    @IBAction func toggleRepeatMode(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDClient.shared.repeatModeToggle()
        }
    }

    @IBAction func toggleSingleMode(_ sender: NSButton) {
        DispatchQueue.global().async {
            MPDClient.shared.singleModeToggle()
        }
    }

    /// Listens to KMBMPDCOptionsReload notifications and updates the main menu
    /// items with the correct values from `MPDClient`.
    @objc func updateModeSelections() {
        consumeModeButton.state = MPDClient.shared.consumeMode ? .on : .off
        randomModeButton.state = MPDClient.shared.randomMode ? .on : .off
        repeatModeButton.state = MPDClient.shared.repeatMode ? .on : .off
        singleModeButton.state = MPDClient.shared.singleMode ? .on : .off
    }

    /// Updates user interface when MPD state or current track changes.
    @objc func updatePlayerStatus() {
        var trackArtist: String = ""
        var trackCover: NSImage? = nil
        var trackTitle: String = "kmbmpdc"
        if let currentTrack = MPDClient.shared.currentTrack {
            trackArtist = currentTrack.artist
            trackCover = currentTrack.coverArt
            trackTitle = currentTrack.name
        }

        DispatchQueue.main.async {
            self.changeImageAssets()
            self.currentTrackArtist.stringValue = trackArtist
            self.currentTrackTitle.stringValue = trackTitle
            self.setCover(trackCover)
            self.stopAfterCurrentButton.state = MPDClient.shared.stopAfterCurrent ? .on : .off
        }
    }

    /// Updates the track queue table when the global `TrackQueue` is updated.
    @objc func updateQueue() {
        DispatchQueue.main.async {
            self.trackQueueTable.reloadData()
        }
    }

}
