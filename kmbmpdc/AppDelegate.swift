import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system().statusItem(withLength: -1)
    let menuBarControls = Controls(nibName: "Controls", bundle: Bundle.main)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menuBarControls?.appDelegate = self
        statusItem.view = menuBarControls?.view
        statusItem.menu = menuBarControls?.mainMenu
        MPDController.sharedController.connect()
    }
}
