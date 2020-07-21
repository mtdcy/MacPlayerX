//
//  AppDelegate.swift
//  mpx
//
//  Created by Chen Fang on 2019/4/12.
//  Copyright © 2019 Chen Fang. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    override init() {
        super.init()
        NSLog("On Application init")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Swift.Bool {
        NSLog("open File: %@", filename)

        let viewController = NSApplication.shared.mainWindow?.contentViewController as? ViewController
        guard viewController != nil else {
            return false
        }
        
        viewController?.openFile(url: filename)
        return true
    }
}

