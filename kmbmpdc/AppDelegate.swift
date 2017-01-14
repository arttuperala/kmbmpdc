import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    let statusItem = NSStatusBar.system().statusItem(withLength: -1)
    let menuBarControls = Controls(nibName: "Controls", bundle: Bundle.main)

    var preferenceWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSUserNotificationCenter.default.delegate = self
        NSUserNotificationCenter.default.removeAllDeliveredNotifications()

        menuBarControls?.appDelegate = self
        statusItem.view = menuBarControls?.view
        statusItem.menu = menuBarControls?.mainMenu
        MPDController.sharedController.connect()
    }

    /// Create a preference window object, tie it to the AppDelegate and launch it.
    func openPreferences() {
        if preferenceWindow == nil {
            let viewController = Preferences()
            viewController.owner = self
            preferenceWindow = NSWindow(contentViewController: viewController)
            let nonResizableMask: UInt = preferenceWindow!.styleMask.rawValue &
                ~NSWindowStyleMask.resizable.rawValue
            preferenceWindow!.styleMask = NSWindowStyleMask(rawValue: nonResizableMask)
            preferenceWindow!.title = "kmbmpdc Preferences"
        }
        preferenceWindow!.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }

}
