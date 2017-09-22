import Cocoa

struct Constants {
    struct Images {
        static let pauseButton = NSImage.Name("PauseButton")
        static let pauseButtonAlt = NSImage.Name("PauseButtonAlt")
        static let placeholderCover = NSImage.Name("PlaceholderCover")
        static let playButton = NSImage.Name("PlayButton")
        static let playButtonAlt = NSImage.Name("PlayButtonAlt")
        static let statusPaused = NSImage.Name("StatusPaused")
        static let statusPlaying = NSImage.Name("StatusPlaying")
    }
    
    struct Nibs {
        static let search = NSNib.Name("Search")
    }
    
    struct Notifications {
        static let changedTrack = Notification.Name("KMBMPDCChangedTrack")
        static let connected = Notification.Name("KMBMPDCConnected")
        static let disconnected = Notification.Name("KMBMPDCDisconnected")
        static let optionsRefresh = Notification.Name("KMBMPDCOptionsReload")
        static let playerRefresh = Notification.Name("KMBMPDCPlayerReload")
        static let playlistRefresh = Notification.Name("KMBMPDCPlaylistReload")
        static let queueRefresh = Notification.Name("KMBMPDCQueueReload")
    }

    struct Preferences {
        static let mpdHost = "MPDHost"
        static let mpdPass = "MPDPassword"
        static let mpdPort = "MPDPort"
        static let musicDirectory = "MusicDirectoryPath"
        static let notificationsDisabled = "NotificationsDisabled"
    }

    struct UserNotifications {
        static let trackChange = "kmbmpdcTrackChange"
    }
}
