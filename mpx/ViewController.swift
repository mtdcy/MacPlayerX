//
//  ViewController.swift
//  mpx
//
//  Created by Chen Fang on 2019/4/12.
//  Copyright © 2019 Chen Fang. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet var mBaseView: BaseView!
    @IBOutlet weak var mOpenGLView: OpenGLView!
    
    var mNativePLayer = NativePlayer()
    var mIsLoaded : Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("View Did Load")
        
        // setup OpenGL Context
        NSLog("OpenGLContext: %@", mOpenGLView.openGLContext!)
        mOpenGLView.prepareOpenGL()
        
        // not working, but still put this line
        self.view.window?.isMovableByWindowBackground = true
    }
    
    override func viewWillDisappear() {
        closeFile()
        
        NSLog("View Will Disappear")
        super.viewWillDisappear()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func openFile() {
        NSLog("Open File...")
        
        let dialog = NSOpenPanel()
        dialog.title                = "Open File..."
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles     = false
        dialog.canChooseFiles       = true
        dialog.canChooseDirectories = false
        dialog.allowsMultipleSelection  = false
        dialog.allowedFileTypes         = ["mp4","mkv","mp3"]
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if (dialog.url != nil) {
                let url = dialog.url!.path
                NSLog("url = %@", url)
                
                mNativePLayer.clear()
                mNativePLayer.setup(url: url)
                mNativePLayer.prepare(us: 0)
                
                mIsLoaded = true
            }
        } else {
            NSLog("Cancel Open File...")
        }
    }
    
    func closeFile() {
        mNativePLayer.clear()
        mIsLoaded = false
    }
    
    override func keyDown(with event: NSEvent) {
        NSLog("keyDown: %@", event)
        
        let c = event.charactersIgnoringModifiers
        if (c == "o") {
            openFile()
        } else if (c == " ") {
            if (mIsLoaded == false) {
                openFile()
            }
            mNativePLayer.startOrPause()
        } else if (c == "q") {
            closeFile()
        }
        
    }
    
    // move window by background
    override func mouseDragged(with event: NSEvent) {
        self.view.window?.performDrag(with: event)
    }
    
    @IBAction func open(sender : Any) {
        openFile()
    }

    @IBAction func close(sender : Any) {
        //self.view.window?.performClose(nil)
        NSApplication.shared.terminate(self)
    }
}

