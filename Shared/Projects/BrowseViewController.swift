//
//  BrowseViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 30.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BrowseViewController: BaseTableViewController {

    class Folder {
        let name: String

        let modifiedDate: Date?

        let original: Any?

        init(_ name: String, _ modifiedDate: Date?, _ original: Any?) {
            self.name = name
            self.modifiedDate = modifiedDate
            self.original = original
        }

        convenience init(_ original: FileInfo) {
            self.init(original.name, original.modifiedDate ?? original.creationDate, original)
        }
    }

    private var loading = true

    var headers = [String]()

    var data = [[Any]]()

    private var selected: IndexPath?


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Browse Existing", comment: "")

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Add", comment: ""), style: .done,
            target: self, action: #selector(done))
        navigationItem.rightBarButtonItem?.isEnabled = false

        tableView.register(FolderCell.nib, forCellReuseIdentifier: FolderCell.reuseId)

        loadFolders()
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return data.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = data[indexPath.section][indexPath.row]

        if let error = item as? Error {
            let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId,
                                                 for: indexPath) as! MenuItemCell

            return cell.set(error)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: FolderCell.reuseId,
                                                 for: indexPath) as! FolderCell

        if let folder = item as? Folder {
            cell.set(folder: folder)
        }

        cell.accessoryType = indexPath.section == selected?.section && indexPath.row == selected?.row ? .checkmark : .none

        return cell
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard indexPath.section < data.count 
                && indexPath.row < data[indexPath.section].count
                && data[indexPath.section][indexPath.row] is Folder
        else {
            return nil
        }

        return indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var rows = [indexPath]

        if let selected = selected {
            rows.append(selected)
        }

        selected = indexPath
        navigationItem.rightBarButtonItem?.isEnabled = true

        tableView.reloadRows(at: rows, with: .none)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section < headers.count && !headers[section].isEmpty ? headers[section] : nil
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section < headers.count && !headers[section].isEmpty ? TableHeader.reducedHeight : 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section > 0 ? MenuItemCell.height : FolderCell.height
    }


    // MARK: Public Methods

    func beginWork(_ block: () -> Void) {
        loading = true

        DispatchQueue.main.async {
            self.workingOverlay.isHidden = false
        }

        block()
    }

    func endWork() {
        self.loading = false

        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.workingOverlay.isHidden = true
        }
    }

    func loadFolders() {
        beginWork {
            data.removeAll()

            if let space = SelectedSpace.space as? WebDavSpace, let url = space.url {
                space.session.info(url) { info, error in
                    if let error = error {
                        self.data.append([error])

                        return
                    }

                    var folders = [Folder]()

                    let files = info.dropFirst().sorted(by: {
                        $0.modifiedDate ?? $0.creationDate ?? Date(timeIntervalSince1970: 0)
                        > $1.modifiedDate ?? $1.creationDate ?? Date(timeIntervalSince1970: 0)
                    })

                    for file in files {
                        if file.type == .directory && !file.isHidden {
                            folders.append(Folder(file))
                        }
                    }

                    self.data.append(folders)

                    self.endWork()
                }
            }
            else {
                self.endWork()
            }
        }
    }


    // MARK: Private Methods

    @objc private func done() {
        guard let selected = selected,
              let space = SelectedSpace.space,
              selected.section < data.count
                && selected.row < data[selected.section].count,
              let folder = data[selected.section][selected.row] as? Folder
        else {
            return
        }

        let alert = DuplicateFolderAlert(nil)

        if alert.exists(spaceId: space.id, name: folder.name) {
            present(alert, animated: true)
            return
        }

        let project = Project(name: folder.name, space: space)

        Db.writeConn?.setObject(project)

        dismiss(animated: true)
    }
}
