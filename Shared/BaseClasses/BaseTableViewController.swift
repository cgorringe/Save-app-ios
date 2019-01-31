//
//  BaseTableViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 31.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BaseTableViewController: UITableViewController {

    lazy var workingOverlay: WorkingOverlay = {
        return WorkingOverlay().addToSuperview(navigationController?.view ?? view)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TableHeader.self, forHeaderFooterViewReuseIdentifier: TableHeader.reuseId)
        tableView.register(MenuItemCell.nib, forCellReuseIdentifier: MenuItemCell.reuseId)

        tableView.tableFooterView = UIView()
    }

    
    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> TableHeader {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: TableHeader.reuseId) as! TableHeader
    }
}