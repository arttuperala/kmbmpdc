import Cocoa

class TrackQueue: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    static let global = TrackQueue()

    var tracks: [Track] = []

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tracks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < tableView.numberOfRows else {
            return nil
        }

        let track = tracks[row]
        if let cell: TrackCell = tableView.make(withIdentifier: tableColumn!.identifier,
                                                owner: self) as? TrackCell {
            cell.generate(for: track)
            return cell
        }
        return nil
    }
}
