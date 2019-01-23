//
//  ProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class ProjectViewController: FormViewController {

    var project: Project?

    private let nameRow = TextRow() {
        $0.title = "Name".localize()
        $0.add(rule: RuleRequired())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "New Project".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(connect))

        nameRow.value = project?.name

        form
            +++ Section()

            <<< LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.textAlignment = .center
                $0.title = "Curate your own project or browse for an existing one.".localize()
            }

            <<< nameRow.cellUpdate() { _, _ in
                self.enableDone()
            }

        form.validate()
        enableDone()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    // MARK: Actions

    @objc func connect() {
        let project = self.project ?? Project()

        project.name = nameRow.value

        Db.newConnection()?.asyncReadWrite() { transaction in
            transaction.setObject(project, forKey: project.id,
                                  inCollection: Project.collection)
        }

        navigationController?.popViewController(animated: true)
    }


    // MARK: Private Methods

    private func enableDone() {
        navigationItem.rightBarButtonItem?.isEnabled = nameRow.isValid
    }
}
