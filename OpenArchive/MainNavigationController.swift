//
//  MainNavigationController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MainNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setRoot()
    }

    func setRoot() {
        performSegue(
            withIdentifier: Settings.firstRunDone ? "mainSegue" : "onboardingSegue",
            sender: self)
    }
}
