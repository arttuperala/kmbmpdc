import Cocoa

class TrackCell: NSTableCellView {
    @IBOutlet weak var titleField: NSTextField!
    @IBOutlet weak var subtitleField: NSTextField!

    /// Generate table cell's user interface based on the given `Track` object.
    func generate(for track: Track) {
        titleField.stringValue = track.name
        subtitleField.stringValue = "\(track.artist) ― \(track.album)"
    }
}
