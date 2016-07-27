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
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(Controls.onConnect),
                                       name: Constants.Notifications.connected, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controls.onDisconnect),
                                       name: Constants.Notifications.disconnected, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controls.updateModeSelections),
                                       name: Constants.Notifications.optionsRefresh, object: nil)
        notificationCenter.addObserver(self, selector: #selector(Controls.updatePlayerStatus),
                                       name: Constants.Notifications.playerRefresh, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        // Set the button images to templates to play nice with dark mode.
        playPauseButton.image?.template = true
        nextButton.image?.template = true
        menuButton.image?.template = true
    }
    
    @IBAction func connectDisconnectWasClicked(sender: AnyObject) {
        if MPDController.sharedController.connected {
            MPDController.sharedController.disconnect()
        } else {
            MPDController.sharedController.connect()
        }
    }
    
    @IBAction func consumeModeWasClicked(sender: AnyObject) {
        MPDController.sharedController.consumeModeToggle()
    }
    
    /// Toggles all the menu controls that are dependent on a MPD connection.
    /// - Parameter enabled: Boolean indicating whether or not controls are enabled.
    func enableControls(enabled: Bool) {
        playPauseMenuButton.enabled = enabled
        stopButton.enabled = enabled
        nextMenuButton.enabled = enabled
        previousButton.enabled = enabled
        consumeMode.enabled = enabled
        randomMode.enabled = enabled
        repeatMode.enabled = enabled
        singleMode.enabled = enabled
    }
    
    func onDisconnect() {
        let bundle = NSBundle.mainBundle()
        let playButtonImage = bundle.imageForResource("PlayIconDisabled")!
        let nextButtonImage = bundle.imageForResource("NextIconDisabled")!
        playButtonImage.template = true
        nextButtonImage.template = true
        playPauseButton.image = playButtonImage
        playPauseButton.alternateImage = playButtonImage
        nextButton.image = nextButtonImage
        nextButton.alternateImage = nextButtonImage
        
        connectDisconnect.title = "Connect"
        enableControls(false)
    }
    
    func onConnect() {
        let bundle = NSBundle.mainBundle()
        let nextButtonImage = bundle.imageForResource("NextIcon")!
        nextButtonImage.template = true
        nextButton.image = nextButtonImage
        nextButton.alternateImage = nextButtonImage
        
        connectDisconnect.title = "Disconnect"
        enableControls(true)
    }
    
    @IBAction func menuWasClicked(sender: AnyObject) {
        guard let delegate = appDelegate else { return }
        delegate.statusItem.popUpStatusItemMenu(mainMenu)
        menuButton.state = 0
    }
    
    @IBAction func nextWasClicked(sender: AnyObject) {
        if MPDController.sharedController.connected {
            MPDController.sharedController.next()
        }
        nextButton.state = 0
    }
    
    @IBAction func nextMenuWasClicked(sender: AnyObject) {
        MPDController.sharedController.next()
    }
    
    @IBAction func playPauseWasClicked(sender: AnyObject) {
        if MPDController.sharedController.connected {
            MPDController.sharedController.playPause()
        }
        playPauseButton.state = 0
    }
    
    @IBAction func playPauseMenuWasClicked(sender: AnyObject) {
        MPDController.sharedController.playPause()
    }
    
    @IBAction func previousWasClicked(sender: AnyObject) {
        MPDController.sharedController.previous()
    }
    
    @IBAction func randomModeWasClicked(sender: AnyObject) {
        MPDController.sharedController.randomModeToggle()
    }
    
    @IBAction func repeatModeWasClicked(sender: AnyObject) {
        MPDController.sharedController.repeatModeToggle()
    }
    
    @IBAction func singleModeWasClicked(sender: AnyObject) {
        MPDController.sharedController.singleModeToggle()
    }
    
    @IBAction func stopWasClicked(sender: AnyObject) {
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
            mainButtonImage = NSBundle.mainBundle().imageForResource("PauseIcon")!
        } else {
            playPauseMenuButton.title = "Play"
            mainButtonImage = NSBundle.mainBundle().imageForResource("PlayIcon")!
        }
        mainButtonImage.template = true
        playPauseButton.image = mainButtonImage
        playPauseButton.alternateImage = mainButtonImage
    }
}
