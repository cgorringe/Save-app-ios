//
//  Header.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class TableHeader: UITableViewHeaderFooterView {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return String(describing: self)
    }

    class var height: CGFloat {
        return 54
    }


    @IBOutlet weak var label: UILabel!
}
