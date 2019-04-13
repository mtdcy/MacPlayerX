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
        
        // setup OpenGL Context
        NSLog("OpenGLContext: %@", mOpenGLView.openGLContext!)
        mOpenGLView.prepareOpenGL()
        
        // not working, but still put this line
        self.view.window?.isMovableByWindowBackground = true
        
        // init values
        mInfoText.stringValue = "OpenGL"
        
        // show UI at beginning
        showUI(visible: true)
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
    func updateUIOnce(title : String?) {
        if (title != nil) {
            self.view.window?.title = title!
        }
        let duration = mNativePLayer.duration()
        mTotalDuration.stringValue = formatTime(seconds: duration)
        updateUI()
    }
    
    func updateUI() {
        let current = mNativePLayer.progress()
        let duration = mNativePLayer.duration()
        
        mCurrentPosition.stringValue = formatTime(seconds: current)
        mPositionSlider.doubleValue = mPositionSlider.maxValue * (current / duration)
    }
    
    func showUI(visible : Bool) {
        if (visible) {
            NSLog("showUI...");
            if (mIsVisible == true) {
                NSLog("showUI: UI is already visible");
            } else {
                self.view.window?.titleVisibility = NSWindow.TitleVisibility.visible
                mPositionStack.isHidden = false
                
                if (mNativePLayer.isOpenGL == true) {
                    mInfoText.isHidden = false
                    Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { (timer : Timer) in
                        self.mInfoText.isHidden = true
                        timer.invalidate()
                    }
                }
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
                updateUIOnce(title: url)
            }
        } else {
            NSLog("Cancel Open File...")
        }
    }
    
    override func keyDown(with event: NSEvent) {
        NSLog("keyDown: %@", event)
        
        let c = event.charactersIgnoringModifiers
        switch (c) {
        case "o":
            openFile()
        case " ":
            mNativePLayer.startOrPause()
        case "q":
            mNativePLayer.clear()
        default:
            break
        }
        
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
    }
}

