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
    @IBOutlet weak var mInfoText: NSTextField!
    
    var mPrefs = Preferences()
    
    var mIsVisible : Bool?              // true, false, nil
    var mUpdater : Timer?
    let mUpdateInterval : Double = 0.2
    var mShowTime : Date?
    let mShowInterval : Double = 5

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
        
        mPrefs.show()
        
        // setup OpenGL Context
        NSLog("OpenGLContext: %@", mOpenGLView.openGLContext!)
        mOpenGLView.prepareOpenGL()
        
        // not working, but still put this line
        self.view.window?.isMovableByWindowBackground = true
        
        // show UI at beginning
        showUI(visible: true)
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
        let current = mNativePLayer.progress()
        let duration = mNativePLayer.duration()
        
        mCurrentPosition.stringValue = formatTime(seconds: current)
        mPositionSlider.doubleValue = mPositionSlider.maxValue * (current / duration)
        mTotalDuration.stringValue = formatTime(seconds: duration)
    }
    
    func showUI(visible : Bool) {
        if (visible) {
            NSLog("showUI...");

            self.view.window?.titleVisibility = NSWindow.TitleVisibility.visible
            mPositionStack.isHidden = false
            
            if (mNativePLayer.isOpenGL == true) {
                mInfoText.isHidden = false
                mInfoText.stringValue = "OpenGL"
            } else {
                mInfoText.isHidden = true
            }
            
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
            mInfoText.isHidden = true
            
            mUpdater?.invalidate()
            mUpdater = nil
            
            mIsVisible = false
        }
    }
    
    func openFile() {
        NSLog("Open File...")
        
        let url = NSDocumentController.shared.urlsFromRunningOpenPanel()
        if (url != nil) {
            NSLog("url = %@", url!)
            let path : String = url![0].path
     
            closeFile()
            mNativePLayer.setup(url: path)
            mNativePLayer.prepare(seconds: 0)
            
            // show ui
            updateUIOnce(title: path)
        } else {
            NSLog("Cancel Open File...")
        }
    }
    
    func closeFile() {
        mNativePLayer.clear()
    }
    
    override func keyDown(with event: NSEvent) {
        NSLog("keyDown: %@", event)
        
        let special = event.specialKey;
        if (special != nil) {
            switch (special) {
            case NSEvent.SpecialKey.rightArrow:
                mNativePLayer.prepare(seconds: mNativePLayer.progress() + 5)
            case NSEvent.SpecialKey.leftArrow:
                mNativePLayer.prepare(seconds: mNativePLayer.progress() - 5)
            default:
                break;
            }
        } else {
            let c = event.charactersIgnoringModifiers
            switch (c) {
            case "o":
                openFile()
            case " ":
                mNativePLayer.startOrPause()
            case "q":
                closeFile()
            default:
                break
            }
            
        }
        
        showUI(visible: true)
    }
    
    override func mouseDown(with event: NSEvent) {
        showUI(visible: true)
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
        showUI(visible: true)
    }
}

