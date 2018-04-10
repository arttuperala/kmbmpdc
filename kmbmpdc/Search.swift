import Cocoa

struct Identifiers {
    static let searchTrackAlbum = NSUserInterfaceItemIdentifier("searchTrackAlbum")
    static let searchTrackArtist = NSUserInterfaceItemIdentifier("searchTrackArtist")
    static let searchTrackLength = NSUserInterfaceItemIdentifier("searchTrackLength")
    static let searchTrackNumber = NSUserInterfaceItemIdentifier("searchTrackNumber")
    static let searchTrackTitle = NSUserInterfaceItemIdentifier("searchTrackTitle")
}

class Search: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var resultTable: NSTableView!

    var results: [Track] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        resetTableSize()
    }

    /// Returns an array of `Track` objects based on what rows are selected in the table.
    var selectedRows: [Track] {
        var tracks: [Track] = []
        if resultTable.selectedRowIndexes.isEmpty {
            tracks.append(results[resultTable.clickedRow])
        } else {
            for index in resultTable.selectedRowIndexes {
                tracks.append(results[index])
            }
        }
        return tracks
    }

    @IBAction func addAfterCurrentAlbum(_ sender: Any) {
        MPDClient.shared.insertAfterCurrentAlbum(selectedRows)
    }

    @IBAction func addAfterCurrentSong(_ sender: Any) {
        MPDClient.shared.insertAfterCurrentTrack(selectedRows)
    }

    @IBAction func addToEnd(_ sender: Any) {
        MPDClient.shared.append(selectedRows)
    }

    @IBAction func addToBeginning(_ sender: Any) {
        MPDClient.shared.insertAtBeginning(selectedRows)
    }

    @IBAction func itemDoubleClicked(_ sender: Any) {
        guard resultTable.clickedRow >= 0, resultTable.clickedRow < results.count else {
            return
        }

        let track = results[resultTable.clickedRow]
        MPDClient.shared.append([track])
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }

    /// Performs the search on the `NSSearchField` string value. Empty string clears the results.
    @IBAction func performSearch(_ sender: NSSearchField) {
        if sender.stringValue.isEmpty {
            results.removeAll()
            resultTable.reloadData()
        } else {
            MPDClient.shared.search(for: sender.stringValue) { results in
                self.results = results
                DispatchQueue.main.async { self.resultTable.reloadData() }
            }
        }
    }

    /// Resizes the table columns to their predefined widths.
    func resetTableSize() {
        for column in resultTable.tableColumns {
            if column.identifier == Identifiers.searchTrackAlbum {
                column.width = 170
            } else if column.identifier == Identifiers.searchTrackArtist {
                column.width = 170
            } else if column.identifier == Identifiers.searchTrackLength {
                column.width = 43
            } else if column.identifier == Identifiers.searchTrackNumber {
                column.width = 29
            } else if column.identifier == Identifiers.searchTrackTitle {
                column.width = 255
            }
        }
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let identifier = tableColumn?.identifier else {
            return nil
        }
        switch identifier {
        case Identifiers.searchTrackAlbum:
            return results[row].album
        case Identifiers.searchTrackArtist:
            return results[row].artist
        case Identifiers.searchTrackLength:
            return results[row].durationString
        case Identifiers.searchTrackNumber:
            return results[row].number
        case Identifiers.searchTrackTitle:
            return results[row].name
        default:
            return nil
        }
    }
}
