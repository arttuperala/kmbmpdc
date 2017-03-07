import Cocoa

class TrackCell: NSTableCellView {
    @IBOutlet weak var coverArt: NSImageView!
    @IBOutlet weak var titleField: NSTextField!
    @IBOutlet weak var subtitleField: NSTextField!

    /// Generate table cell's user interface based on the given `Track` object.
    func generate(for track: Track) {
        coverArt.image = track.coverArt
        titleField.stringValue = track.name
        subtitleField.stringValue = "\(track.artist) ― \(track.album)"

        // Draw border around cover art.
        coverArt.wantsLayer = true
        coverArt.layer?.borderColor = NSColor.disabledControlTextColor.cgColor
        coverArt.layer?.borderWidth = 1.0
        coverArt.layer?.cornerRadius = 4.0
        coverArt.layer?.masksToBounds = true
    }
}
