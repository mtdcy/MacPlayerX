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
    @IBOutlet weak var mOpenGLText: NSTextField!
    
    var mIsVisible : Bool?              // true, false, nil
    var mUpdater : Timer?
    let mUpdateInterval : Double = 0.2

    var mNativePLayer = NativePlayer()
    
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
        
        // init values
        mOpenGLText.stringValue = "OpenGL"
        
        // hide UI at beginning
        showUI(visible: false)
    }
    
    override func viewWillDisappear() {
        mNativePLayer.clear()
        
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
    
    // update elements once, like title
    func updateUIOnce(title : String) {
        self.view.window?.title = title
        updateUI()
    }
    
    func updateUI() {
        let current = mNativePLayer.progress()
        let duration = mNativePLayer.duration()
        
        mCurrentPosition.stringValue = formatTime(seconds: current)
        mTotalDuration.stringValue = formatTime(seconds: duration)
        mPositionSlider.doubleValue = mPositionSlider.maxValue * (current / duration)
        
        if (mNativePLayer.isPlaying == false) {
            NSLog("updateUI: player has stopped")
            mUpdater?.invalidate()
            mUpdater = nil
        }
    }
    
    func showUI(visible : Bool) {
        if (visible) {
            if (mIsVisible == true) {
                NSLog("showUI: UI is already visible");
            } else {
                self.view.window?.titleVisibility = NSWindow.TitleVisibility.visible
                mPositionStack.isHidden = false
                
                if (mNativePLayer.isOpenGL == true) {
                    mOpenGLText.isHidden = false
                    Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { (timer : Timer) in
                        self.mOpenGLText.isHidden = true
                        timer.invalidate()
                    }
                }
            }
            
            if (mUpdater != nil) {
                return;
            }
            
            // start a timer to update ui
            mUpdater = Timer.scheduledTimer(withTimeInterval: mUpdateInterval, repeats: true, block: { (Timer) in
                self.updateUI()
            })
            updateUI()
            
            mIsVisible = true
        } else {
            self.view.window?.titleVisibility = NSWindow.TitleVisibility.hidden
            mPositionStack.isHidden = true
            mOpenGLText.isHidden = true
            
            mUpdater?.invalidate()
            mUpdater = nil
            
            mIsVisible = false
        }
    }
    
    func openFile() {
        NSLog("Open File...")
        
        mNativePLayer.clear()
        
        let dialog = NSOpenPanel()
        dialog.title                    = "Open File..."
        dialog.showsResizeIndicator     = true
        dialog.showsHiddenFiles         = false
        dialog.canChooseFiles           = true
        dialog.canChooseDirectories     = false
        dialog.allowsMultipleSelection  = false
        dialog.allowedFileTypes         = ["mp4","mkv","mp3"]
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if (dialog.url != nil) {
                let url = dialog.url!.path
                NSLog("url = %@", url)
                
                mNativePLayer.setup(url: url)
                mNativePLayer.prepare(seconds: 0)
                
                // show ui
                showUI(visible: true)
                updateUIOnce(title: url)
            }
        } else {
            NSLog("Cancel Open File...")
        }
    }
    
    override func keyDown(with event: NSEvent) {
        NSLog("keyDown: %@", event)
        
        let c = event.charactersIgnoringModifiers
        if (c == "o") {
            openFile()
        } else if (c == " ") {
            if (mNativePLayer.startOrPause() == true) {
                showUI(visible: true)
            }
        } else if (c == "q") {
            mNativePLayer.clear()
        } else if (c == "z") {
            if (mIsVisible == true) {
                showUI(visible: false)
            } else {
                showUI(visible: true)
            }
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

