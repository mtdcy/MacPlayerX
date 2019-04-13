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
    var mTimer : Timer?
    
    func formatTime(seconds : Double) -> String {
        let _seconds = Int64(seconds)
        let h = _seconds / 3600
        let m = (_seconds % 3600) / 60
        let s = _seconds % 60
        if (h > 0) {
            return String.init(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String.init(format: "%02d:%02d", m, s)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("View Did Load")
        
        // setup OpenGL Context
        NSLog("OpenGLContext: %@", mOpenGLView.openGLContext!)
        mOpenGLView.prepareOpenGL()
        
        // not working, but still put this line
        self.view.window?.isMovableByWindowBackground = true
        
        mCurrentPosition.stringValue = formatTime(seconds: 0)
        mTotalDuration.stringValue = formatTime(seconds: 0)
    }
    
    override func viewWillDisappear() {
        closeFile()
        
        NSLog("View Will Disappear")
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
    
    dynamic func updateUIOnce(title : String) {
        self.view.window?.title = title
    }
    
    dynamic func updateUI() {
        let current = mNativePLayer.progress()
        let duration = mNativePLayer.duration()
        
        mCurrentPosition.stringValue = formatTime(seconds: current)
        mTotalDuration.stringValue = formatTime(seconds: duration)
        mPositionSlider.doubleValue = mPositionSlider.maxValue * (current / duration)
        
        if (mNativePLayer.isPlaying == false) {
            // stop timer
            mTimer?.invalidate()
            mTimer = nil
        }
    }
    
    func openFile() {
        NSLog("Open File...")
        
        mNativePLayer.clear()
        
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
                
                mNativePLayer.setup(url: url)
                mNativePLayer.prepare(seconds: 0)
                
                mIsLoaded = true
                updateUIOnce(title: url)
            }
        } else {
            NSLog("Cancel Open File...")
        }
        
        updateUI()
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
            if (mNativePLayer.startOrPause() == true) {
                
                mTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (Timer) in
                    self.updateUI()
                })
                
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
    
    @IBAction func seek(sender : Any) {
        let sec = mNativePLayer.duration() * mPositionSlider.doubleValue / mPositionSlider.maxValue;
        NSLog("seek to %@", sec)
        mNativePLayer.prepare(seconds: sec)
    }
}

