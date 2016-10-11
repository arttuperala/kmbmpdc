import Cocoa
import libmpdclient

class Controls: NSViewController {
    @IBOutlet weak var connectDisconnect: NSMenuItem!
    @IBOutlet weak var consumeMode: NSMenuItem!
    @IBOutlet weak var mainMenu: NSMenu!
    @IBOutlet weak var menuButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var nextMenuButton: NSMenuItem!
    @IBOutlet weak var playPauseButton: NSButton!
    @IBOutlet weak var playPauseMenuButton: NSMenuItem!
    @IBOutlet weak var previousButton: NSMenuItem!
    @IBOutlet weak var randomMode: NSMenuItem!
    @IBOutlet weak var repeatMode: NSMenuItem!
    @IBOutlet weak var singleMode: NSMenuItem!
    @IBOutlet weak var stopButton: NSMenuItem!

    var appDelegate: AppDelegate?

    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(Controls.onConnect),
                                       name: NSNotification.Name(rawValue: Constants.Notifications.connected), object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controls.onDisconnect),
                                       name: NSNotification.Name(rawValue: Constants.Notifications.disconnected), object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controls.updateModeSelections),
                                       name: NSNotification.Name(rawValue: Constants.Notifications.optionsRefresh), object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controls.updatePlayerStatus),
                                       name: NSNotification.Name(rawValue: Constants.Notifications.playerRefresh), object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        // Set the button images to templates to play nice with dark mode.
        playPauseButton.image?.isTemplate = true
        nextButton.image?.isTemplate = true
        menuButton.image?.isTemplate = true
    }

    @IBAction func connectDisconnectWasClicked(_ sender: AnyObject) {
        if MPDController.sharedController.connected {
            MPDController.sharedController.disconnect()
        } else {
            MPDController.sharedController.connect()
        }
    }

    @IBAction func consumeModeWasClicked(_ sender: AnyObject) {
        MPDController.sharedController.consumeModeToggle()
    }

    /// Toggles all the menu controls that are dependent on a MPD connection.
    /// - Parameter enabled: Boolean indicating whether or not controls are enabled.
    func enableControls(_ enabled: Bool) {
        playPauseMenuButton.isEnabled = enabled
        stopButton.isEnabled = enabled
        nextMenuButton.isEnabled = enabled
        previousButton.isEnabled = enabled
        consumeMode.isEnabled = enabled
        randomMode.isEnabled = enabled
        repeatMode.isEnabled = enabled
        singleMode.isEnabled = enabled
    }

    func onDisconnect() {
        let bundle = Bundle.main
        let playButtonImage = bundle.image(forResource: "PlayIconDisabled")!
        let nextButtonImage = bundle.image(forResource: "NextIconDisabled")!
        playButtonImage.isTemplate = true
        nextButtonImage.isTemplate = true
        playPauseButton.image = playButtonImage
        playPauseButton.alternateImage = playButtonImage
        nextButton.image = nextButtonImage
        nextButton.alternateImage = nextButtonImage

        connectDisconnect.title = "Connect"
        enableControls(false)
    }

    func onConnect() {
        let bundle = Bundle.main
        let nextButtonImage = bundle.image(forResource: "NextIcon")!
        nextButtonImage.isTemplate = true
        nextButton.image = nextButtonImage
        nextButton.alternateImage = nextButtonImage

        connectDisconnect.title = "Disconnect"
        enableControls(true)
    }

    @IBAction func menuWasClicked(_ sender: AnyObject) {
        guard let delegate = appDelegate else { return }
        delegate.statusItem.popUpMenu(mainMenu)
        menuButton.state = 0
    }

    @IBAction func nextWasClicked(_ sender: AnyObject) {
        if MPDController.sharedController.connected {
            MPDController.sharedController.next()
        }
        nextButton.state = 0
    }

    @IBAction func nextMenuWasClicked(_ sender: AnyObject) {
        MPDController.sharedController.next()
    }

    @IBAction func playPauseWasClicked(_ sender: AnyObject) {
        if MPDController.sharedController.connected {
            MPDController.sharedController.playPause()
        }
        playPauseButton.state = 0
    }

    @IBAction func playPauseMenuWasClicked(_ sender: AnyObject) {
        MPDController.sharedController.playPause()
    }

    @IBAction func previousWasClicked(_ sender: AnyObject) {
        MPDController.sharedController.previous()
    }

    @IBAction func randomModeWasClicked(_ sender: AnyObject) {
        MPDController.sharedController.randomModeToggle()
    }

    @IBAction func repeatModeWasClicked(_ sender: AnyObject) {
        MPDController.sharedController.repeatModeToggle()
    }

    @IBAction func singleModeWasClicked(_ sender: AnyObject) {
        MPDController.sharedController.singleModeToggle()
    }

    @IBAction func stopWasClicked(_ sender: AnyObject) {
        MPDController.sharedController.stop()
    }

    /// Listens to KMBMPDCOptionsReload notifications and updates the main menu
    /// items with the correct values from MPDController.
    func updateModeSelections() {
        consumeMode.state = Int(MPDController.sharedController.consumeMode)
        randomMode.state = Int(MPDController.sharedController.randomMode)
        repeatMode.state = Int(MPDController.sharedController.repeatMode)
        singleMode.state = Int(MPDController.sharedController.singleMode)
    }

    func updatePlayerStatus() {
        var mainButtonImage: NSImage
        if MPDController.sharedController.playerState == MPD_STATE_PLAY {
            playPauseMenuButton.title = "Pause"
            mainButtonImage = Bundle.main.image(forResource: "PauseIcon")!
        } else {
            playPauseMenuButton.title = "Play"
            mainButtonImage = Bundle.main.image(forResource: "PlayIcon")!
        }
        mainButtonImage.isTemplate = true
        playPauseButton.image = mainButtonImage
        playPauseButton.alternateImage = mainButtonImage
    }
}
