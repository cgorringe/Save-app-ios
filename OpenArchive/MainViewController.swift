//
//  MainViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import MobileCoreServices
import Photos
import YapDatabase

class MainViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    lazy var imagePicker: UIImagePickerController = {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
        imagePicker.modalPresentationStyle = .popover

        return imagePicker
    }()

    lazy var readConn: YapDatabaseConnection? = {
        let conn = Db.newConnection()
        conn?.beginLongLivedReadTransaction()

        return conn
    }()

    lazy var mappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: AssetsView.groups, view: AssetsView.name)

        readConn?.read() { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    lazy var writeConn = Db.newConnection()

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseModified),
                                               name: .YapDatabaseModified,
                                               object: readConn?.database)

        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseModifiedExternally),
                                               name: .YapDatabaseModifiedExternally,
                                               object: readConn?.database)
    }

    // MARK: actions

    @IBAction func add(_ sender: UIBarButtonItem) {
        imagePicker.popoverPresentationController?.barButtonItem = sender

        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            present(imagePicker, animated: true)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization() { newStatus in
                if newStatus == .authorized {
                    self.present(self.imagePicker, animated: true)
                }
            }

        case .restricted:
            AlertHelper.present(
                self, message: "Sorry, you are not allowed to view the photo library.".localize(),
                title: "Access Restricted".localize(),
                actions: [AlertHelper.cancelAction()])

        case .denied:
            AlertHelper.present(
                self,
                message: "Please go to the Settings app to grant this app access to your photo library, if you want to upload photos or videos.".localize(),
                title: "Access Denied".localize(),
                actions: [AlertHelper.cancelAction()])
        }
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ImageCell.HEIGHT
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ImageCell", for: indexPath) as! ImageCell

        readConn?.read() { transaction in
            cell.asset = (transaction.ext(AssetsView.name) as? YapDatabaseViewTransaction)?
                .object(at: indexPath, with: self.mappings) as? Asset
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete,
            let key = (tableView.cellForRow(at: indexPath) as? ImageCell)?.asset?.id {

            writeConn?.asyncReadWrite() { transaction in
                transaction.removeObject(forKey: key, inCollection: Asset.collection)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = DetailsViewController()

        if let imageCell = tableView.cellForRow(at: indexPath) as? ImageCell {
            vc.asset = imageCell.asset
        }

        if let navVC = navigationController {
            navVC.pushViewController(vc, animated: true)
        }
        else {
            present(vc, animated: true)
        }
    }

    // MARK: UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo
        info: [UIImagePickerController.InfoKey : Any]) {
        
        if let type = info[.mediaType] as? String,
            let url = info[.referenceURL] as? URL {

            AssetFactory.create(fromAlAssetUrl: url, mediaType: type) { asset in
                self.writeConn?.asyncReadWrite() { transaction in
                    transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
                }
            }
        }

        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
    */
    @objc func yapDatabaseModified(notification: Notification) {
        if let readConn = readConn {
            var changes = NSArray()

            (readConn.ext(AssetsView.name) as? YapDatabaseViewConnection)?
                .getSectionChanges(nil,
                                   rowChanges: &changes,
                                   for: readConn.beginLongLivedReadTransaction(),
                                   with: mappings)

            if let changes = changes as? [YapDatabaseViewRowChange],
                changes.count > 0 {

                tableView.beginUpdates()

                for change in changes {
                    switch change.type {
                    case .delete:
                        if let indexPath = change.indexPath {
                            tableView.deleteRows(at: [indexPath], with: .automatic)
                        }
                    case .insert:
                        if let newIndexPath = change.newIndexPath {
                            tableView.insertRows(at: [newIndexPath], with: .automatic)
                        }
                    case .move:
                        if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                            tableView.moveRow(at: indexPath, to: newIndexPath)
                        }
                    case .update:
                        if let indexPath = change.indexPath {
                            tableView.reloadRows(at: [indexPath], with: .none)
                        }
                    }
                }

                tableView.endUpdates()
            }
        }
    }

    /**
     Callback for `YapDatabaseModifiedExternally` notification.

     Will be called, when something outside the process (e.g. in the share extension) changed
     the database.
     */
    @objc func yapDatabaseModifiedExternally(notification: Notification) {
        readConn?.beginLongLivedReadTransaction()

        readConn?.read() { transaction in
            self.mappings.update(with: transaction)

            self.tableView.reloadData()
        }
    }
}
