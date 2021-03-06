import Cocoa

class Preferences: NSViewController {
    @IBOutlet weak var hostField: NSTextField!
    @IBOutlet weak var portField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!
    @IBOutlet weak var musicDirectoryPath: NSPathControl!
    @IBOutlet weak var notificationEnableButton: NSButton!

    var owner: AppDelegate?
    let defaults = UserDefaults.standard

    var mpdHost: String {
        get {
            return defaults.string(forKey: Constants.Preferences.mpdHost) ?? ""
        }
        set(stringValue) {
            defaults.set(stringValue, forKey: Constants.Preferences.mpdHost)
        }
    }

    var mpdPassword: String {
        get {
            return defaults.string(forKey: Constants.Preferences.mpdPass) ?? ""
        }
        set(stringValue) {
            if stringValue.isEmpty {
                defaults.set(nil, forKey: Constants.Preferences.mpdPass)
            } else {
                defaults.set(stringValue, forKey: Constants.Preferences.mpdPass)
            }
        }
    }

    var mpdPort: String {
        get {
            let port = defaults.integer(forKey: Constants.Preferences.mpdPort)
            if port > 0 {
                return String(port)
            } else {
                return ""
            }
        }
        set(stringValue) {
            if let port = Int(stringValue) {
                defaults.set(port, forKey: Constants.Preferences.mpdPort)
            } else {
                portField.stringValue = ""
                defaults.set(0, forKey: Constants.Preferences.mpdPort)
            }
        }
    }

    var musicDirectory: URL {
        get {
            if let url = defaults.url(forKey: Constants.Preferences.musicDirectory) {
                return url
            } else {
                return URL(fileURLWithPath: NSHomeDirectory())
            }
        }
        set(url) {
            defaults.set(url, forKey: Constants.Preferences.musicDirectory)
        }
    }

    var notificationsDisabled: NSControl.StateValue {
        get {
            let disabled = defaults.bool(forKey: Constants.Preferences.notificationsDisabled)
            return disabled ? .off : .on
        }
        set(state) {
            let disabled = state == .off ? true : false
            defaults.set(disabled, forKey: Constants.Preferences.notificationsDisabled)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hostField.stringValue = mpdHost
        portField.stringValue = mpdPort
        passwordField.stringValue = mpdPassword
        musicDirectoryPath.url = musicDirectory
        notificationEnableButton.state = notificationsDisabled
    }

    override func viewWillDisappear() {
        mpdHost = hostField.stringValue
        mpdPort = portField.stringValue
        mpdPassword = passwordField.stringValue
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        owner?.preferenceWindow = nil
    }

    @IBAction func changedHost(_ sender: NSTextField) {
        mpdHost = sender.stringValue
    }

    @IBAction func changedPassword(_ sender: NSTextField) {
        mpdPassword = sender.stringValue
    }

    @IBAction func changedPort(_ sender: NSTextField) {
        mpdPort = sender.stringValue
    }

    @IBAction func notificationsToggled(_ sender: NSButton) {
        notificationsDisabled = sender.state
    }

    @IBAction func openMusicDirectorySelector(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = musicDirectoryPath.url
        let panelAction = panel.runModal()
        if panelAction == .OK {
            musicDirectoryPath.url = panel.url
            musicDirectory = panel.url!
        }
    }

}
