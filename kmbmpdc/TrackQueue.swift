import Cocoa

class TrackQueue: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    static let global = TrackQueue()

    var tracks: [Track] = []

    func numberOfRows(in tableView: NSTableView) -> Int {
        return TrackQueue.global.tracks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell: TrackCell = tableView.make(withIdentifier: tableColumn!.identifier,
                                                owner: self) as? TrackCell {
            cell.generate(for: TrackQueue.global.tracks[row])
            return cell
        }
        return nil
    }
}
