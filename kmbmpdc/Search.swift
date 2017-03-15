import Cocoa

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
        for index in resultTable.selectedRowIndexes {
            tracks.append(results[index])
        }
        return tracks
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
        } else {
            results = MPDClient.shared.search(for: sender.stringValue)
        }
        resultTable.reloadData()
    }

    /// Resizes the table columns to their predefined widths.
    func resetTableSize() {
        for column in resultTable.tableColumns {
            if column.identifier == "searchTrackAlbum" {
                column.width = 170
            } else if column.identifier == "searchTrackArtist" {
                column.width = 170
            } else if column.identifier == "searchTrackLength" {
                column.width = 43
            } else if column.identifier == "searchTrackNumber" {
                column.width = 29
            } else if column.identifier == "searchTrackTitle" {
                column.width = 255
            }
        }
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?,
                   row: Int) -> Any? {
        switch tableColumn?.identifier {
        case "searchTrackAlbum"?:
            return results[row].album
        case "searchTrackArtist"?:
            return results[row].artist
        case "searchTrackLength"?:
            return results[row].durationString
        case "searchTrackNumber"?:
            return results[row].number
        case "searchTrackTitle"?:
            return results[row].name
        default:
            return nil
        }
    }
}
