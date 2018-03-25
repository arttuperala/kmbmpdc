import Cocoa
import libmpdclient
import imeji

class Track: NSObject {
    let identifier: Int32
    let name: String
    let uri: String
    let album: String
    let artist: String
    let number: Int?
    let duration: Int?

    var coverArt: NSImage?

    convenience init(identifier: Int32) {
        let trackInfo = MPDClient.shared.lookupSong(identifier: identifier)
        self.init(trackInfo: trackInfo)
        self.coverArt = self.getCoverArt()
    }

    init(trackInfo: OpaquePointer) {
        self.identifier = Int32(exactly: mpd_song_get_id(trackInfo))!
        self.name = Track.getTag(trackInfo: trackInfo, tagType: MPD_TAG_TITLE)
        self.album = Track.getTag(trackInfo: trackInfo, tagType: MPD_TAG_ALBUM)
        self.artist = Track.getTag(trackInfo: trackInfo, tagType: MPD_TAG_ARTIST)
        self.number = Int(Track.getTag(trackInfo: trackInfo, tagType: MPD_TAG_TRACK))
        self.duration = Int(exactly: mpd_song_get_duration(trackInfo))
        self.uri = String(cString: mpd_song_get_uri(trackInfo))
        mpd_song_free(trackInfo)
    }

    func getCoverArt() -> NSImage? {
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

        if let image = Track.getID3CoverArt(filePath.path) {
            return image
        }

        return nil
    }

    var durationString: String {
        guard let duration = self.duration else {
            return ""
        }
        let minutes = String(duration / 60)
        let seconds = String(format: "%02d", duration % 60)

        return "\(minutes):\(seconds)"
    }

    static func getID3CoverArt(_ path: String) -> NSImage? {
        guard check_id3_identifier(path) == 1 else {
            return nil
        }
        let apic = get_id3_picture_data(path)
        var image: NSImage?
        if apic.size > 0 {
            let imageData = Data(bytes: apic.data, count: apic.size)
            image = NSImage(data: imageData)
        }
        free_picture_data(apic)
        return image
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
