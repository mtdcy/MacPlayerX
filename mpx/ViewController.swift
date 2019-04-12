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
    
    @IBOutlet weak var mPositionStack: NSStackView!
    @IBOutlet weak var mCurrentPosition: NSTextField!
    @IBOutlet weak var mTotalDuration: NSTextField!
    @IBOutlet weak var mPositionSlider: NSSlider!
    
    
    var mNativePLayer = NativePlayer()
    var mIsLoaded : Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("View Did Load")
        
        // setup OpenGL Context
        print("OpenGLContext: ", mOpenGLView.openGLContext!)
        mOpenGLView.prepareOpenGL()
        
        // not working, but still put this line
        self.view.window?.isMovableByWindowBackground = true
    }
    
    override func viewWillDisappear() {
        closeFile()
        
        print("View Will Disappear")
        super.viewWillDisappear()
        
        // close application on player gone
        // this line should only exists in one place in the application
        NSApplication.shared.terminate(self)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func openFile() {
        print("Open File...")
        
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
                print("url = ", url)
                
                mNativePLayer.clear()
                mNativePLayer.setup(url: url)
                mNativePLayer.prepare(seconds: 0)
                
                mIsLoaded = true
            }
        } else {
            print("Cancel Open File...")
        }
    }
    
    func closeFile() {
        mNativePLayer.clear()
        mIsLoaded = false
    }
    
    override func keyDown(with event: NSEvent) {
        print("keyDown: ", event)
        
        let c = event.charactersIgnoringModifiers
        if (c == "o") {
            openFile()
        } else if (c == " ") {
            if (mIsLoaded == false) {
                openFile()
            }
            if (mNativePLayer.startOrPause() == true) {
            }
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
        self.view.window?.performClose(nil)
    }
}

