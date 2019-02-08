//
//  BaseDetailsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class BaseDetailsViewController: UIViewController {

    static let ccDomain = "creativecommons.org"
    static let ccUrl = "https://%@/licenses/%@/4.0/"

    static let serverBoxHeight: CGFloat = 72

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var innerViewHeightCt: NSLayoutConstraint!
    @IBOutlet var image: UIImageView!
    @IBOutlet var typeLb: UILabel!
    @IBOutlet var dateLb: UILabel!
    @IBOutlet var serverBox: UIView!
    @IBOutlet var serverBoxHeightCt: NSLayoutConstraint!
    @IBOutlet var serverNameLb: UILabel!
    @IBOutlet var serverStatusLb: UILabel!
    @IBOutlet var serverUrlLb: UILabel!
    @IBOutlet var titleTf: UITextField!
    @IBOutlet var descriptionTf: UITextField!
    @IBOutlet var authorTf: UITextField!
    @IBOutlet var locationTf: UITextField!
    @IBOutlet var tagsTf: UITextField!
    @IBOutlet var licenseTf: UITextField!
    @IBOutlet var remixSw: UISwitch!
    @IBOutlet var shareAlikeSw: UISwitch!
    @IBOutlet var commercialSw: UISwitch!

    var asset: Asset?

    var innerViewHeight: CGFloat!

    init() {
        super.init(nibName: "BaseDetailsViewController", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        innerViewHeight = innerViewHeightCt.constant

        // Add upload button.
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "CloudUpload"),
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(upload(_:)))

        // Add Gesture Recognizer so the user can hide the keyboard again by tapping somewhere else
        // than the text field.
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))

        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(didShowKeyboard(_:)),
                                               name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didHideKeyboard(_:)),
                                               name: UIResponder.keyboardDidHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidHideNotification, object: nil)

        super.viewWillDisappear(animated)
    }

    // MARK: Public Methods

    /**
     (Re-)renders the scene evaluating the latest `asset`.
    */
    public func render() {
        DispatchQueue.main.async {
            if let asset = self.asset {
                self.image.image = asset.getThumbnail()

                self.typeLb.text = asset.mimeType

                self.dateLb.text = Formatters.date.string(from: asset.created)

                if asset.isUploaded {
                    self.setServerInfo()
                }
                else {
                    self.showServerBox(false, animated: false)
                }

                self.titleTf.text = asset.title
                self.descriptionTf.text = asset.desc
                self.authorTf.text = asset.author
                self.locationTf.text = asset.location
                self.tagsTf.text = asset.tags?.joined(separator: ", ")
                self.licenseTf.text = asset.license

                if let license = asset.license,
                    license.localizedCaseInsensitiveContains(BaseDetailsViewController.ccDomain) {

                    self.remixSw.isOn = !license.localizedCaseInsensitiveContains("-nd")
                    self.shareAlikeSw.isEnabled = self.remixSw.isOn
                    self.shareAlikeSw.isOn = self.shareAlikeSw.isEnabled && license.localizedCaseInsensitiveContains("-sa")
                    self.commercialSw.isOn = !license.localizedCaseInsensitiveContains("-nc")
                }
            }
            else {
                self.image.image = nil
                self.dateLb.text = nil
                self.showServerBox(false, animated: false)

                self.titleTf.text = nil
                self.descriptionTf.text = nil
                self.authorTf.text = nil
                self.locationTf.text = nil
                self.tagsTf.text = nil
                self.licenseTf.text = nil
            }
        }
    }

    // MARK: Keyboard handling

    /**
     Callback for NotificationCenter .UIKeyboardDidShow observer.

     Adjusts the bottom inset of the scrollView, so the user can always scroll the full scene.

     - parameter notification: Provided by NotificationCenter.
     */
    @objc func didShowKeyboard(_ notification: Notification) {
        if let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {

            let bottom = keyboardFrame.cgRectValue.height
            scrollView?.contentInset.bottom = bottom
            scrollView?.scrollIndicatorInsets.bottom = bottom
        }
    }

    /**
     Callback for NotificationCenter .UIKeyboardDidHide observer.

     Adjusts the bottom inset of the scrollView, so the user can always scroll the full scene.

     - parameter notification: Provided by NotificationCenter.
     */
    @objc func didHideKeyboard(_ notification: Notification) {
        scrollView?.contentInset.bottom = 0
        scrollView?.scrollIndicatorInsets.bottom = 0
    }

    /**
     Dismisses the keyboard by ending editing on the main view.

     - parameter sender: The sending UITapGestureRecognizer.
     */
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    // MARK: Actions

    @IBAction func removeFromServer(_ button: UIButton) {
        if let asset = asset,
            let space = asset.space {

            button.isHidden = true

            serverStatusLb.text = "Removing...".localize()

            space.remove(asset) { asset in
                self.setServerStatus()

                button.isHidden = false

                if asset.error == nil && !asset.isUploaded {
                    self.showServerBox(false)

                    Db.writeConn?.asyncReadWrite() { transaction in
                        transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
                    }
                }
                else {
                    self.setServerStatus()
                }
            }
        }
    }

    @IBAction func contentChanged(_ sender: UITextField) {
        if let asset = asset {
            switch sender {
            case titleTf:
                asset.title = titleTf.text
            case descriptionTf:
                asset.desc = descriptionTf.text
            case authorTf:
                asset.author = authorTf.text
            case locationTf:
                asset.location = locationTf.text
            case tagsTf:
                let t = tagsTf.text?.split(separator: ",")
                var tags = [String]()

                t?.forEach() { tag in
                    tags.append(tag.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                asset.tags = tags

            case licenseTf:
                asset.license = licenseTf.text
            default:
                assertionFailure("This should have never happened - switch should be exhaustive.")
            }

            Db.writeConn?.asyncReadWrite() { transaction in
                transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
            }
        }
    }

    @IBAction func ccLicenseChanged(_ sender: UISwitch) {
        var license = "by"

        if remixSw.isOn {
            shareAlikeSw.isEnabled = true

            if !commercialSw.isOn {
                license += "-nc"
            }

            if shareAlikeSw.isOn {
                license += "-sa"
            }
        } else {
            shareAlikeSw.isEnabled = false
            shareAlikeSw.setOn(false, animated: true)

            if !commercialSw.isOn {
                license += "-nc"
            }

            license += "-nd"
        }

        licenseTf.text = String(format: BaseDetailsViewController.ccUrl, BaseDetailsViewController.ccDomain,
                                license)

        contentChanged(licenseTf)
    }

    @objc func upload(_ sender: UIBarButtonItem) {
        if let asset = asset,
            let space = asset.space {

            var firstTime = true

            space.upload(asset, progress: { asset, progress in
                if firstTime {
                    self.setServerInfo()
                    firstTime = false
                }

                let progressFormatted = Formatters.integer.string(for: progress.fractionCompleted * 100)
                    ?? "Unknown".localize()

                self.serverStatusLb.text = "Progress: %".localize(value: "\(progressFormatted)%")
            }) { server in
                self.setServerInfo()

                Db.writeConn?.asyncReadWrite() { transaction in
                    transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
                }
            }
        }
        else {
            AlertHelper.present(
                self,
                message: "This asset doesn't belong to a space, yet!\n\nPlease configure the asset's project accordingly.".localize(),
                title: "Project Configuration".localize(),
                actions: [AlertHelper.cancelAction()])
        }
    }

    private func setServerInfo() {
        serverNameLb.text = asset?.space?.prettyName

        setServerStatus()

        serverUrlLb.text = asset?.publicUrl?.absoluteString

        showServerBox(true)
    }

    private func setServerStatus() {
        if let error = asset?.error, error.count > 0 {
            self.serverStatusLb.text = error
            print(error)
        }
        else if asset?.isUploaded ?? false {
            self.serverStatusLb.text = "Uploaded".localize()
        }
        else {
            serverStatusLb.text = "Not uploaded".localize()
        }
    }

    private func showServerBox(_ toggle: Bool, animated: Bool = true) {
        if toggle {
            navigationItem.rightBarButtonItem?.isEnabled = false

            serverBox.isHidden = false

            if animated {
                UIView.animate(withDuration: 1) {
                    self.serverBoxHeightCt.constant = BaseDetailsViewController.serverBoxHeight
                    self.view.layoutIfNeeded()
                }
            }
            else {
                serverBoxHeightCt.constant = BaseDetailsViewController.serverBoxHeight
            }

            innerViewHeightCt.constant = innerViewHeight
        }
        else {
            navigationItem.rightBarButtonItem?.isEnabled = true

            serverBox.isHidden = true

            if animated {
                UIView.animate(withDuration: 1) {
                    self.serverBoxHeightCt.constant = 0
                    self.view.layoutIfNeeded()
                }
            }
            else {
                serverBoxHeightCt.constant = 0
            }

            innerViewHeightCt.constant = innerViewHeight - BaseDetailsViewController.serverBoxHeight
        }
    }
}
