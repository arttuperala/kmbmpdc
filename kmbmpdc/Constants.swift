import Cocoa

struct Constants {
    struct Images {
        static let pauseButton = "PauseButton"
        static let pauseButtonAlt = "PauseButtonAlt"
        static let placeholderCover = "PlaceholderCover"
        static let playButton = "PlayButton"
        static let playButtonAlt = "PlayButtonAlt"
        static let statusPaused = "StatusPaused"
        static let statusPlaying = "StatusPlaying"
    }

    struct Nibs {
        static let search = "Search"
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
