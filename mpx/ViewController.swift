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

    
    var mPrefs = Preferences()
    
    var mIsVisible : Bool?              // true, false, nil
    var mUpdater : Timer?
    let mUpdateInterval : Double = 0.2
    var mShowTime : Date?
    let mShowInterval : Double = 5

    var mTiger = Tiger()
    
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
        
        // set background color
        self.view.wantsLayer = true;
        self.view.layer?.backgroundColor = NSColor.black.cgColor
        
        mPrefs.show()
        
        // setup OpenGL Context
        NSLog("OpenGLContext: %@", mOpenGLView.openGLContext!)
        mOpenGLView.openGLContext?.makeCurrentContext()
        
        // not working, but still put this line
        self.view.window?.isMovableByWindowBackground = true
        
        // show UI at beginning
        showUI(visible: false)
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
    
    // update elements once, like title
    func updateUIOnce(title : String?) {
        if (title != nil) {
            self.view.window?.title = title!
        }
        updateUI()
    }
    
    func updateUI() {
        let current = mTiger.currentPosition
        let duration = mTiger.duration
        
        mCurrentPosition.stringValue = formatTime(seconds: current)
        mTotalDuration.stringValue = formatTime(seconds: duration)
        
        // only update slider when playing
        if (mTiger.isPlaying) {
            mPositionSlider.doubleValue = mPositionSlider.maxValue * (current / duration)
        }
    }
    
    func showUI(visible : Bool) {
        if (visible) {
            NSLog("showUI...");

            self.view.window?.titleVisibility = NSWindow.TitleVisibility.visible
            mPositionStack.isHidden = false
            
            updateUIOnce(title: nil)
            mShowTime = Date()
            // start a timer to update ui
            if (mUpdater == nil) {
                mUpdater = Timer.scheduledTimer(withTimeInterval: mUpdateInterval, repeats: true, block: { (timer : Timer) in
                    self.updateUI()
                    
                    // hide ui after a while
                    guard let showTime = self.mShowTime else {
                        return
                    }
                    let now = Date()
                    if (showTime + self.mShowInterval < now) {
                        self.showUI(visible: false)
                    }
                })
            }
            
            mIsVisible = true
        } else {
            NSLog("hideUI...")
            self.view.window?.titleVisibility = NSWindow.TitleVisibility.hidden
            mPositionStack.isHidden = true
            
            mUpdater?.invalidate()
            mUpdater = nil
            
            mIsVisible = false
        }
    }
    
    public func openFile(url : String) {
        NSLog("url = %@", url)
        
        let openGLContext = mOpenGLView.openGLContext?.cglContextObj
        mTiger.setup(url: url, openGL : openGLContext)
        
        // show ui
        showUI(visible: true)
    }
    
    func openFile() {
        NSLog("Open File...")
        
        let url = NSDocumentController.shared.urlsFromRunningOpenPanel()
        if (url != nil) {
            self.view.window?.title = url![0].lastPathComponent
            openFile(url: url![0].path)
        } else {
            NSLog("Cancel Open File...")
        }
    }
    
    func closeFile() {
        mTiger.clear()
    }
    
    override func keyDown(with event: NSEvent) {
        NSLog("keyDown: %@", event)
        
        let special = event.specialKey;
        if (special != nil) {
            if (!event.modifierFlags.isEmpty) {
                return
            }
            
            switch (special) {
            case NSEvent.SpecialKey.rightArrow:
                mTiger.prepare(seconds: mTiger.currentPosition + 5)
            case NSEvent.SpecialKey.leftArrow:
                mTiger.prepare(seconds: mTiger.currentPosition - 5)
            default:
                break;
            }
        } else {
            let c = event.charactersIgnoringModifiers
            switch (c) {
            case "o":
                openFile()
            case " ":
                mTiger.startOrPause()
            case "q":
                closeFile()
            default:
                break
            }
            
        }
        
        showUI(visible: true)
    }
    
    override func mouseDown(with event: NSEvent) {
        if (event.clickCount > 1) {
            self.view.window?.toggleFullScreen(self);
        } else {
            showUI(visible: true)
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
        let sec = mTiger.duration * mPositionSlider.doubleValue / mPositionSlider.maxValue;
        NSLog("seek to %@", sec)
        mTiger.prepare(seconds: sec)
        showUI(visible: true)
    }
}

