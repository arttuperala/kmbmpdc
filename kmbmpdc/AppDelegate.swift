import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    let menuBarControls = Controls(nibName: "Controls", bundle: NSBundle.mainBundle())

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        menuBarControls?.appDelegate = self
        statusItem.view = menuBarControls?.view
        statusItem.menu = menuBarControls?.mainMenu
        MPDController.sharedController.connect()
    }
}
