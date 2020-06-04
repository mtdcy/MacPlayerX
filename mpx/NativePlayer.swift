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
    
    var mLooper : LooperObjectRef?
    var mHandle : MediaPlayerRef?
    var mClock : MediaClockRef?
    var mMediaOut : MediaOutRef?
    var mFileInfo : SharedObjectRef?
    
    var mLock : NSLock = NSLock()
    var mMediaFrame : MediaFrameRef?
    
    var mIsVideoToolboxEnabled : Bool = false   // kInfoVideoToolboxEnabled
    var mIsPlaying : Bool = false
    
    var isOpenGL : Bool {
        return mIsVideoToolboxEnabled;
    }
    
    var isPlaying : Bool {
        return mIsPlaying
    }
    
    var currentPosition : Double {
        if (mClock == nil) {
            return 0
        }
        return Double(MediaClockGetTime(mClock)) / 1E6
    }
    
    var duration : Double {
        if (mFileInfo == nil) {
            return 0
        }
        return Double(MessageObjectGetInt64(mFileInfo, kKeyDuration, 0)) / 1E6
    }
    
    func onPlayerInfo(info : ePlayerInfoType, payload : MessageObjectRef?) {
        NSLog("Player Info -> %d", info.rawValue)
        switch (info) {
        case kInfoPlayerReady:
            NSLog("player is ready")
            assert(payload != nil)
            mFileInfo = SharedObjectRetain(payload)
        case kInfoPlayerPlaying:
            mIsPlaying = true
        case kInfoPlayerPaused, kInfoEndOfFile:
            mIsPlaying = false
        case kInfoVideoToolboxEnabled:
            mIsVideoToolboxEnabled = true
        default:
            break
        }
    }
    
    func draw() {
        mLock.lock()
        guard mMediaFrame != nil else {
            NSLog("nil MediaFrame")
            if (mMediaOut != nil) {
                MediaOutFlush(mMediaOut)
            }
            mLock.unlock()
            return
        }
        
        if (mMediaOut == nil) {
            let imageFormat : UnsafeMutablePointer<ImageFormat> = MediaFrameGetImageFormat(mMediaFrame)
            let format  = MessageObjectCreate();
            let options = MessageObjectCreate();
            
            MessageObjectPutInt32(format, kKeyFormat, Int32(imageFormat.pointee.format.rawValue))
            MessageObjectPutInt32(format, kKeyWidth, imageFormat.pointee.width)
            MessageObjectPutInt32(format, kKeyHeight, imageFormat.pointee.height)
            MessageObjectPutInt32(format, kKeyCodecType, Int32(kCodecTypeVideo.rawValue));
            
            mMediaOut = MediaOutCreate(format, options);
                        
            if (imageFormat.pointee.format == kPixelFormatVideoToolbox) {
                mIsVideoToolboxEnabled = true;
            } else {
                mIsVideoToolboxEnabled = false;
            }
            
            SharedObjectRelease(format)
            SharedObjectRelease(options)
        }
        
        MediaOutWrite(mMediaOut, mMediaFrame)
        mLock.unlock()
    }
    
    func onVideoUpdate(current : MediaFrameRef?) {
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
    
    func onAudioUpdate(current : MediaFrameRef?) {
        guard current != nil else {
            NSLog("nil audio frame")
            return
        }
        
        // TODO
    }
    
    override init() {
        NSLog("NativePlayer init")
        // setup log callback
        // https://originware.com/blog/?p=265
        LogSetCallback { (line : UnsafePointer<Int8>?) in
            // print won't send to syslog
            NSLog(String.init(cString: line!))
        }
    }
    
    public func setup(url : String) {
        NSLog("setup")

        clear()
        
        mLooper = LooperObjectCreate("NativePlayer")
        
        // setup options
        let media : MessageObjectRef    = MessageObjectCreate()
        let options : MessageObjectRef  = MessageObjectCreate()
        
        MessageObjectPutString(media, "url", url)
        
        let OnInfoUpdate : PlayerInfoEventRef = PlayerInfoEventCreate(
            mLooper,    // LooperObjectRef
            // PlayerInfoCallback
        {
            (info : ePlayerInfoType, payload : MessageObjectRef?, user : UnsafeMutableRawPointer?) in
            let context : NativePlayer = Unmanaged.fromOpaque(user!).takeUnretainedValue()
            context.onPlayerInfo(info: info, payload: payload)
        },
        Unmanaged.passUnretained(self).toOpaque()   // user context
        )
        MessageObjectPutObject(options, "PlayerInfoEvent", OnInfoUpdate)
        SharedObjectRelease(OnInfoUpdate)

        // MediaFrame Callback
        let OnVideoUpdate : FrameEventRef = FrameEventCreate(
            mLooper,
        {
            (current : MediaFrameRef?, user : UnsafeMutableRawPointer?) in
            let context : NativePlayer = Unmanaged.fromOpaque(user!).takeUnretainedValue()
            context.onVideoUpdate(current: current)
        }, Unmanaged.passUnretained(self).toOpaque())
        MessageObjectPutObject(media, "VideoFrameEvent", OnVideoUpdate)
        SharedObjectRelease(OnVideoUpdate)
        
        NSLog("MediaPlayerCreate")
        mHandle = MediaPlayerCreate(media, options)
        assert(mHandle != nil)
        
        mClock  = MediaPlayerGetClock(mHandle)
        assert(mClock != nil)
        
        // release refs
        SharedObjectRelease(media)
        SharedObjectRelease(options)
    }
    
    public func prepare(seconds : Double) {
        if (mHandle != nil) {
            NSLog("MediaPlayerPrepare")
            MediaPlayerPrepare(mHandle, Int64(seconds * 1E6))
        }
    }
    
    public func startOrPause() -> Bool {
        if (mHandle != nil) {
            if (isPlaying == true) {
                NSLog("MediaPlayerPause")
                MediaPlayerPause(mHandle)
                return false
            } else {
                NSLog("MediaPlayerStart")
                MediaPlayerStart(mHandle)
                return true
            }
        }
        return false
    }
    
    public func clear() {
        if (mHandle != nil) {
            NSLog("MediaPlayerRelease");
            SharedObjectRelease(mHandle)
            mHandle = nil
        }
        
        if (mClock != nil) {
            SharedObjectRelease(mClock)
            mClock = nil
        }
        
        if (mFileInfo != nil) {
            SharedObjectRelease(mFileInfo)
            mFileInfo = nil
        }
        
        if (mMediaOut != nil) {
            MediaOutFlush(mMediaOut)
            SharedObjectRelease(mMediaOut)
            mMediaOut = nil
        }
        
        if (mMediaFrame != nil) {
            SharedObjectRelease(mMediaFrame)
            mMediaFrame = nil
        }
        
        if (mLooper != nil) {
            SharedObjectRelease(mLooper)
            mLooper = nil
        }
    }
}
