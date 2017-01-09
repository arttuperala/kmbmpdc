import Cocoa
import libmpdclient
import Maku

class Track: NSObject {
    let identifier: Int32
    let name: String
    let uri: String
    let album: String
    let artist: String

    init(identifier: Int32) {
        self.identifier = identifier
        let trackInfo = MPDController.sharedController.lookupSong(identifier: self.identifier)
        self.name = Track.getTag(trackInfo: trackInfo, tagType: MPD_TAG_TITLE)
        self.album = Track.getTag(trackInfo: trackInfo, tagType: MPD_TAG_ALBUM)
        self.artist = Track.getTag(trackInfo: trackInfo, tagType: MPD_TAG_ARTIST)
        self.uri = String(cString: mpd_song_get_uri(trackInfo))
        mpd_song_free(trackInfo)
    }

    var coverArt: NSImage? {
        guard let filePath = self.path else {
            return nil
        }

        let basePath = filePath.deletingLastPathComponent()
        for filename in ["cover.jpg", "cover.png"] {
            let filePath = basePath.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: filePath.path) {
                return NSImage(byReferencing: filePath)
            }
        }

        if let tags = try? ID3v2(path: filePath) {
            return tags.attachedPictures.first?.image
        }

        return nil
    }

    static func getTag(trackInfo: OpaquePointer, tagType: mpd_tag_type) -> String {
        if let tagData = mpd_song_get_tag(trackInfo, tagType, 0) {
            return String(cString: tagData)
        } else {
            return ""
        }
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
