import Cocoa
import libmpdclient

class Track: NSObject {
    let identifier: Int32
    let name: String
    let uri: String
    let album: String
    let artist: String

    init(identifier: Int32) {
        self.identifier = identifier
        let trackInfo = MPDController.sharedController.lookupSong(identifier: self.identifier)
        self.name = String(cString: mpd_song_get_tag(trackInfo, MPD_TAG_TITLE, 0))
        self.album = String(cString: mpd_song_get_tag(trackInfo, MPD_TAG_ALBUM, 0))
        self.artist = String(cString: mpd_song_get_tag(trackInfo, MPD_TAG_ARTIST, 0))
        self.uri = String(cString: mpd_song_get_uri(trackInfo))
        mpd_song_free(trackInfo)
    }

    var coverArt: NSImage? {
        guard let basePath = self.path?.deletingLastPathComponent() else { return nil }

        for filename in ["cover.jpg", "cover.png"] {
            let filePath = basePath.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: filePath.path) {
                return NSImage(byReferencing: filePath)
            }
        }

        return nil
    }

    var path: URL? {
        let defaults = UserDefaults.standard
        guard let root = defaults.url(forKey: Constants.Preferences.musicDirectory) else {
            return nil
        }

        let path = URL(fileURLWithPath: self.uri, relativeTo: root)
        if FileManager.default.fileExists(atPath: path.path) {
            return path
        } else {
            return nil
        }
    }

}
