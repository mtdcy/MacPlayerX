//
//  PrefsViewController.swift
//  mpx
//
//  Created by Chen Fang on 2019/4/11.
//  Copyright © 2019 Chen Fang. All rights reserved.
//

import Cocoa

class PrefsViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("Prefs View Did Load")
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        NSLog("Prefs View Will Disappear")
    }
    
    @IBAction func close(sender : Any) {
        NSLog("Close Prefs Window...")
        self.view.window?.performClose(nil)
    }
}
