//
//  NativePlayer.swift
//  mpx
//
//  Created by Chen Fang on 2019/4/10.
//  Copyright © 2019 Chen Fang. All rights reserved.
//

import Foundation
import Cocoa

protocol PlayerProtocol {
    func currentPosition(_ player : NativePlayer)
}

// https://stackoverflow.com/questions/40014717/swift-3-cannot-recognize-the-macro-function
// complex macros are not available in swift

class NativePlayer : NSObject {
    //var mDelegate : PlayerProtocol?
    
    var mHandle : MediaPlayerRef?
    var mClock : MediaClockRef?
    var mInfo : MessageRef?
    var mMediaOut : MediaOutRef?
    
    var mLock : NSLock = NSLock()
    var mMediaFrame : MediaFrameRef?
    
    var mIsOpenGLEnabled : Bool = false         // kInfoOpenGLEnabled
    var mIsVideoToolboxEnabled : Bool = false   // kInfoVideoToolboxEnabled
    var mIsPlaying : Bool = false
    
    var isOpenGL : Bool {
        return mIsOpenGLEnabled == true && mIsVideoToolboxEnabled == true
    }
    
    var isPlaying : Bool {
        return mIsPlaying
    }
    
    func onPlayerInfo(info : eInfoType) {
        switch (info) {
        case kInfoPlayerPlaying:
            mIsPlaying = true
        case kInfoPlayerPaused, kInfoEndOfStream, kInfoPlayerFlushed, kInfoPlayerReleased:
            mIsPlaying = false
        case kInfoOpenGLEnabled:
            mIsOpenGLEnabled = true
        case kInfoVideoToolboxEnabled:
            mIsVideoToolboxEnabled = true
        default:
            NSLog("Player Info -> %d", info.rawValue)
        }
    }
    
    func draw() {
        mLock.lock()
        guard mMediaFrame != nil else {
            NSLog("nil MediaFrame")
            if (mMediaOut != nil) {
                MediaOutFlush(mMediaOut)
            }
            return
        }
        
        if (mMediaOut == nil) {
            self.mMediaOut = MediaOutCreate(kCodecTypeVideo)
            
            let imageFormat : UnsafeMutablePointer<ImageFormat> = MediaFrameGetImageFormat(self.mMediaFrame)
            
            let format = SharedMessageCreate();
            SharedMessagePutInt32(format, kKeyFormat, Int32(imageFormat.pointee.format.rawValue))
            SharedMessagePutInt32(format, kKeyWidth, imageFormat.pointee.width)
            SharedMessagePutInt32(format, kKeyHeight, imageFormat.pointee.height)
            
            let options = SharedMessageCreate();
            if (MediaFrameGetOpaque(mMediaFrame) != nil) {
                SharedMessagePutInt32(options, kKeyOpenGLCompatible, 1)
            }
            MediaOutPrepare(self.mMediaOut, format, options)
            
            SharedObjectRelease(format)
            SharedObjectRelease(options)
        }
        
        MediaOutWrite(self.mMediaOut, mMediaFrame)
        mLock.unlock()
    }
    
    func updateMediaFrame(current : MediaFrameRef?) {
        //NSLog("FrameCallback");
        if (current != nil) {
            mLock.lock()
            if (mMediaFrame != nil) {
                SharedObjectRelease(mMediaFrame)
                mMediaFrame = nil
            }
            mMediaFrame = SharedObjectRetain(current)
            mLock.unlock()
        }
        
        DispatchQueue.main.async {
            self.draw()
        }
    }
    
    override init() {
        NSLog("NativePlayer init")
        // setup log callback
        // https://originware.com/blog/?p=265
        LogSetCallback { (line : UnsafePointer<Int8>?) in
            print(String.init(cString: line!))
        }
    }
    
    public func progress() -> Double {
        if (mClock == nil) {
            return 0
        }
        return Double(MediaClockGetTime(mClock)) / 1E6
    }
    
    public func duration() -> Double {
        if (mInfo == nil) {
            return 0
        }
        let _duration = SharedMessageGetInt64(mInfo, kKeyDuration, 0)
        return Double(_duration) / 1E6;
    }
    
    public func setup(url : String) {
        NSLog("setup")

        clear()
        
        // setup options
        let options : MessageRef = SharedMessageCreate()
        
        // MediaFrame Callback
        let OnFrameUpdate : FrameEventRef = FrameEventCreate({ (current : MediaFrameRef?, user : UnsafeMutableRawPointer?) in
            let context : NativePlayer = Unmanaged.fromOpaque(user!).takeUnretainedValue()
            context.updateMediaFrame(current: current)
        }, Unmanaged.passUnretained(self).toOpaque())
        SharedMessagePutObject(options, "MediaFrameEvent", OnFrameUpdate)
        SharedObjectRelease(OnFrameUpdate)
        
        let OnInfoUpdate : InfoEventRef = InfoEventCreate({ (info : eInfoType, user : UnsafeMutableRawPointer?) in
            let context : NativePlayer = Unmanaged.fromOpaque(user!).takeUnretainedValue()
            context.onPlayerInfo(info: info)
        }, Unmanaged.passUnretained(self).toOpaque())
        SharedMessagePutObject(options, "InfomationEvent", OnInfoUpdate)
        SharedObjectRelease(OnInfoUpdate)

        let media : MessageRef = SharedMessageCreate()
        SharedMessagePutString(media, "url", url)
        
        NSLog("MediaPlayerCreate");
        mHandle = MediaPlayerCreate(media, options)
        mClock = MediaPlayerGetClock(mHandle)
        mInfo = MediaPlayerGetInfo(mHandle)
        
        // release refs
        SharedObjectRelease(options)
        SharedObjectRelease(media)
    }
    
    public func prepare(seconds : Double) {
        if (mHandle != nil) {
            NSLog("MediaPlayerPrepare");
            MediaPlayerPrepare(mHandle, Int64(seconds * 1E6))
        }
    }
    
    public func startOrPause() -> Bool {
        if (mHandle != nil) {
            let state = MediaPlayerGetState(mHandle)
            if (state == kStatePlaying) {
                NSLog("MediaPlayerPause");
                MediaPlayerPause(mHandle)
                return false
            } else if (state == kStateReady || state == kStateIdle) {
                NSLog("MediaPlayerStart");
                MediaPlayerStart(mHandle)
                return true
            } else {
                NSLog("MediaPlayer bad state")
            }
        }
        return false
    }
    
    public func flush() {
        if (mHandle != nil) {
            NSLog("MediaPlayerFlush");
            let state = MediaPlayerGetState(mHandle)
            if (state == kStatePlaying) {
                MediaPlayerPause(mHandle)
            }
            MediaPlayerFlush(mHandle)
        }
    }
    
    public func clear() {
        if (mHandle != nil) {
            NSLog("MediaPlayerRelease");
            let state = MediaPlayerGetState(mHandle)
            if (state == kStatePlaying) {
                MediaPlayerPause(mHandle)
                MediaPlayerFlush(mHandle)
            } else if (state == kStateIdle) {
                MediaPlayerFlush(mHandle)
            }
            
            MediaPlayerRelease(mHandle)
            mHandle = nil
        }
        
        if (mClock != nil) {
            SharedObjectRelease(mClock)
            mClock = nil
        }
        
        if (mInfo != nil) {
            SharedObjectRelease(mInfo)
            mInfo = nil
        }
        
        if (mMediaOut != nil) {
            SharedObjectRelease(mMediaOut)
            mMediaOut = nil
        }
        
        if (mMediaFrame != nil) {
            SharedObjectRelease(mMediaFrame)
            mMediaFrame = nil
        }
    }
}
