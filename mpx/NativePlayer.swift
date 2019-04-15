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
        if (mInfo == nil) {
            return 0
        }
        return Double(SharedMessageGetInt64(mInfo, kKeyDuration, 0)) / 1E6
    }
    
    func onPlayerInfo(info : ePlayerInfoType) {
        NSLog("Player Info -> %d", info.rawValue)
        switch (info) {
        case kInfoPlayerReady:
            mInfo = MediaPlayerGetInfo(mHandle)
            assert(mInfo != nil)
            mClock = MediaPlayerGetClock(mHandle)
            assert(mClock != nil)
        case kInfoPlayerPlaying:
            mIsPlaying = true
        case kInfoPlayerPaused, kInfoEndOfFile, kInfoPlayerFlushed, kInfoPlayerReleased:
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
            mMediaOut = MediaOutCreate(kCodecTypeVideo)
            
            let imageFormat : UnsafeMutablePointer<ImageFormat> = MediaFrameGetImageFormat(mMediaFrame)
            
            if (imageFormat.pointee.format == kPixelFormatVideoToolbox) {
                mIsVideoToolboxEnabled = true;
            } else {
                mIsVideoToolboxEnabled = false;
            }
            
            let format = SharedMessageCreate();
            SharedMessagePutInt32(format, kKeyFormat, Int32(imageFormat.pointee.format.rawValue))
            SharedMessagePutInt32(format, kKeyWidth, imageFormat.pointee.width)
            SharedMessagePutInt32(format, kKeyHeight, imageFormat.pointee.height)
            
            let options = SharedMessageCreate();
            MediaOutPrepare(mMediaOut, format, options)
            
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
        
        // setup options
        let options : MessageRef = SharedMessageCreate()
        
        let OnInfoUpdate : PlayerInfoEventRef = PlayerInfoEventCreate({ (info : ePlayerInfoType, user : UnsafeMutableRawPointer?) in
            let context : NativePlayer = Unmanaged.fromOpaque(user!).takeUnretainedValue()
            context.onPlayerInfo(info: info)
        }, Unmanaged.passUnretained(self).toOpaque())
        SharedMessagePutObject(options, "PlayerInfoEvent", OnInfoUpdate)
        SharedObjectRelease(OnInfoUpdate)

        let media : MessageRef = SharedMessageCreate()
        SharedMessagePutString(media, "url", url)
        
        // MediaFrame Callback
        let OnVideoUpdate : FrameEventRef = FrameEventCreate({ (current : MediaFrameRef?, user : UnsafeMutableRawPointer?) in
            let context : NativePlayer = Unmanaged.fromOpaque(user!).takeUnretainedValue()
            context.onVideoUpdate(current: current)
        }, Unmanaged.passUnretained(self).toOpaque())
        SharedMessagePutObject(media, "VideoFrameEvent", OnVideoUpdate)
        SharedObjectRelease(OnVideoUpdate)
        
        NSLog("MediaPlayerCreate")
        mHandle = MediaPlayerCreate(media, options)
        assert(mHandle != nil)
        
        // release refs
        SharedObjectRelease(options)
        SharedObjectRelease(media)
    }
    
    public func prepare(seconds : Double) {
        if (mHandle != nil) {
            NSLog("MediaPlayerPrepare")
            assert(MediaPlayerPrepare(mHandle, Int64(seconds * 1E6)) == kMediaNoError)
        }
    }
    
    public func startOrPause() -> Bool {
        if (mHandle != nil) {
            if (isPlaying == true) {
                NSLog("MediaPlayerPause")
                assert(MediaPlayerPause(mHandle) == kMediaNoError)
                return false
            } else {
                NSLog("MediaPlayerStart")
                assert(MediaPlayerStart(mHandle) == kMediaNoError)
                return true
            }
        }
        return false
    }
    
    public func flush() {
        if (mHandle != nil) {
            NSLog("MediaPlayerFlush");
            assert(MediaPlayerFlush(mHandle) == kMediaNoError)
        }
    }
    
    public func clear() {
        if (mHandle != nil) {
            NSLog("MediaPlayerRelease");
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
            MediaOutFlush(mMediaOut)
            SharedObjectRelease(mMediaOut)
            mMediaOut = nil
        }
        
        if (mMediaFrame != nil) {
            SharedObjectRelease(mMediaFrame)
            mMediaFrame = nil
        }
    }
}
