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
    // FIXME: switch to queue
    var mMediaFrame : MediaFrameRef?
    
    func onPlayerInfo(info : eInfoType) {
        switch (info) {
        case kInfoEndOfStream:
            NSLog("EOS")
            //case kInfoPlayerReady..kInfoPlayerReleased:
            
        default:
            NSLog("Player Info -> %d", info.rawValue)
        }
    }
    
    func updateMediaFrame(current : MediaFrameRef?) {
        //NSLog("FrameCallback");
        if (current != nil) {
            mMediaFrame = SharedObjectRetain(current)
        }
        
        DispatchQueue.main.async {
            //NSLog("drawMediaFrame in main")
            
            if (self.mMediaFrame == nil) {
                NSLog("nil MediaFrame")
                if (self.mMediaOut != nil) {
                    MediaOutFlush(self.mMediaOut)
                }
                return
            }
            
            if (self.mMediaOut == nil) {
                self.mMediaOut = MediaOutCreate(kCodecTypeVideo)
                
                let imageFormat : UnsafeMutablePointer<ImageFormat> = MediaFrameGetImageFormat(self.mMediaFrame)
                
                let format = SharedMessageCreate();
                SharedMessagePutInt32(format, kKeyFormat, Int32(imageFormat.pointee.format.rawValue))
                SharedMessagePutInt32(format, kKeyWidth, imageFormat.pointee.width)
                SharedMessagePutInt32(format, kKeyHeight, imageFormat.pointee.height)
                
                let options = SharedMessageCreate();
                if (MediaFrameGetOpaque(current) != nil) {
                    SharedMessagePutInt32(options, kKeyOpenGLCompatible, 1)
                }
                MediaOutPrepare(self.mMediaOut, format, options)
                
                SharedObjectRelease(format)
                SharedObjectRelease(options)
            }
            
            MediaOutWrite(self.mMediaOut, current)
            
            SharedObjectRelease(self.mMediaFrame)
            self.mMediaFrame = nil
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
    
    var isPlaying : Bool {
        if (mHandle == nil) {
            return false
        } else {
            return MediaPlayerGetState(mHandle) == kStatePlaying
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
            
            SharedObjectRelease(mClock)
            mClock = nil
            SharedObjectRelease(mInfo)
            mInfo = nil
            
            // FIXME: may block
            MediaPlayerRelease(mHandle)
            mHandle = nil
        }
    }
}
