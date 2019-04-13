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

typealias CLogCallback = @convention(c)(UnsafePointer<Int8>?) -> Void
typealias CFrameCallback = @convention(c)(MediaFrameRef?, UnsafeMutableRawPointer?) -> Void
typealias CPositionCallback = @convention(c)(Int64, UnsafeMutableRawPointer?) -> Void

class NativePlayer : NSObject {
    //var mDelegate : PlayerProtocol?
    
    var mHandle : MediaPlayerRef?
    var mClock : MediaClockRef?
    var mInfo : MessageRef?
    
    class MediaOutContext {
        var mMediaOut : MediaOutRef?
        // FIXME: switch to queue
        var mMediaFrame : MediaFrameRef?
    }
    var mMediaOutContext : MediaOutContext!
    
    override init() {
        print("NativePlayer init")
        // setup log callback
        // https://originware.com/blog/?p=265
        let callback : CLogCallback = { (line : UnsafePointer<Int8>?) -> Void in
            NSLog(String.init(cString: line!))
        }
        LogSetCallback(callback)
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
        print("setup")

        clear()
        
        // setup options
        var options : MessageRef = SharedMessageCreate()
        let FrameCallback : CFrameCallback = { (current : MediaFrameRef?, user : UnsafeMutableRawPointer?) -> Void in
            if (current == nil) {
                print("FrameCallback: nil MediaFrameRef")
            } else {
                //NSLog("FrameCallback");
                let context : MediaOutContext = Unmanaged.fromOpaque(user!).takeUnretainedValue()
                if (current != nil) {
                    context.mMediaFrame = SharedObjectRetain(current)
                }
                
                DispatchQueue.main.async {
                    //NSLog("drawMediaFrame in main")
                    
                    if (context.mMediaFrame == nil) {
                        print("nil MediaFrame")
                        if (context.mMediaOut != nil) {
                            MediaOutFlush(context.mMediaOut)
                        }
                        return
                    }
                    
                    if (context.mMediaOut == nil) {
                        context.mMediaOut = MediaOutCreate(kCodecTypeVideo)
                        
                        let imageFormat : UnsafeMutablePointer<ImageFormat> = MediaFrameGetImageFormat(context.mMediaFrame)
                        
                        var format = SharedMessageCreate();
                        SharedMessagePutInt32(format, kKeyFormat, Int32(imageFormat.pointee.format.rawValue))
                        SharedMessagePutInt32(format, kKeyWidth, imageFormat.pointee.width)
                        SharedMessagePutInt32(format, kKeyHeight, imageFormat.pointee.height)
                        
                        var options = SharedMessageCreate();
                        if (MediaFrameGetOpaque(current) != nil) {
                            SharedMessagePutInt32(options, kKeyOpenGLCompatible, 1)
                        }
                        MediaOutPrepare(context.mMediaOut, format, options)
                        
                        SharedObjectRelease(format)
                        SharedObjectRelease(options)
                    }
                    
                    MediaOutWrite(context.mMediaOut, current)
                    
                    SharedObjectRelease(context.mMediaFrame)
                    context.mMediaFrame = nil
                }
            }
        }
        
        // MediaFrame Callback
        mMediaOutContext = MediaOutContext()
        let user = Unmanaged.passUnretained(mMediaOutContext!).toOpaque()
        let OnFrameUpdate : FrameEventRef = FrameEventCreate(FrameCallback, user)
        SharedMessagePutObject(options, "MediaFrameEvent", OnFrameUpdate)
        SharedObjectRelease(OnFrameUpdate)

/*
        let PositionCallback : CPositionCallback = { (pos : Int64, user : UnsafeMutableRawPointer?) -> Void in
            NSLog("PositionCallback")
        }
        let OnPositionUpdate : PositionEventRef = PositionEventCreate(PositionCallback, nil)
        SharedMessagePutObject(options, "RenderPositionEvent", OnPositionUpdate)
        SharedObjectRelease(OnPositionUpdate)
*/
        var media : MessageRef = SharedMessageCreate()
        SharedMessagePutString(media, "url", url)
        
        print("MediaPlayerCreate");
        mHandle = MediaPlayerCreate(media, options)
        mClock = MediaPlayerGetClock(mHandle)
        mInfo = MediaPlayerGetInfo(mHandle)
        
        // release refs
        SharedObjectRelease(options)
        SharedObjectRelease(media)
    }
    
    public func prepare(seconds : Double) {
        if (mHandle != nil) {
            print("MediaPlayerPrepare");
            MediaPlayerPrepare(mHandle, Int64(seconds * 1E6))
        }
    }
    
    public func startOrPause() -> Bool {
        if (mHandle != nil) {
            let state = MediaPlayerGetState(mHandle)
            if (state == kStatePlaying) {
                print("MediaPlayerPause");
                MediaPlayerPause(mHandle)
                return false
            } else if (state == kStateReady || state == kStateIdle) {
                print("MediaPlayerStart");
                MediaPlayerStart(mHandle)
                return true
            } else {
                print("MediaPlayer bad state")
            }
        }
        return false
    }
    
    public func flush() {
        if (mHandle != nil) {
            print("MediaPlayerFlush");
            let state = MediaPlayerGetState(mHandle)
            if (state == kStatePlaying) {
                MediaPlayerPause(mHandle)
            }
            MediaPlayerFlush(mHandle)
        }
    }
    
    public func clear() {
        if (mHandle != nil) {
            print("MediaPlayerRelease");
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
