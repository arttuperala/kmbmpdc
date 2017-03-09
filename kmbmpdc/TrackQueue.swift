import Cocoa

class TrackQueue: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    static let global = TrackQueue()

    var tracks: [Track] = []

    func numberOfRows(in tableView: NSTableView) -> Int {
        return TrackQueue.global.tracks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < tableView.numberOfRows else {
            return nil
        }

        let track = TrackQueue.global.tracks[row]
        if let cell: TrackCell = tableView.make(withIdentifier: tableColumn!.identifier,
                                                owner: self) as? TrackCell {
            cell.generate(for: track)
            return cell
        }
        return nil
    }
}
