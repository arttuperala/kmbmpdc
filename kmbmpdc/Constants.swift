import Foundation

struct Constants {
    struct Notifications {
        static let connected = Notification.Name("KMBMPDCConnected")
        static let disconnected = Notification.Name("KMBMPDCDisconnected")
        static let optionsRefresh = Notification.Name("KMBMPDCOptionsReload")
        static let playerRefresh = Notification.Name("KMBMPDCPlayerReload")
    }
}
