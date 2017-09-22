import Cocoa

class TrackQueue: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    static let global = TrackQueue()

    var tracks: [Track] = []

    /// Returns the track for the given index or nil if index is not found.
    func get(_ index: Int) -> Track? {
        guard index >= 0, index < tracks.count else {
            return nil
        }
        return tracks[index]
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tracks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < tableView.numberOfRows else {
            return nil
        }

        let track = tracks[row]
        if let cell: TrackCell = tableView.makeView(withIdentifier: tableColumn!.identifier,
                                                owner: self) as? TrackCell {
            cell.generate(for: track)
            return cell
        }
        return nil
    }
}
