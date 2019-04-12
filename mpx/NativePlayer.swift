//
//  NativePlayer.swift
//  mpx
//
//  Created by Chen Fang on 2019/4/10.
//  Copyright © 2019 Chen Fang. All rights reserved.
//

import Foundation
import Cocoa

// https://stackoverflow.com/questions/40014717/swift-3-cannot-recognize-the-macro-function
// complex macros are not available in swift

typealias CLogCallback = @convention(c)(UnsafePointer<Int8>?) -> Void
typealias CFrameCallback = @convention(c)(MediaFrameRef?, UnsafeMutableRawPointer?) -> Void
typealias CPositionCallback = @convention(c)(Int64, UnsafeMutableRawPointer?) -> Void

class NativePlayer : NSObject {
    var mHandle : MediaPlayerRef!
    
    class MediaOutContext {
        var mMediaOut : MediaOutRef?
        // FIXME: switch to queue
        var mMediaFrame : MediaFrameRef?
    }
    var mMediaOutContext : MediaOutContext!
    
    override init() {
        NSLog("NativePlayer init")
        // setup log callback
        // https://originware.com/blog/?p=265
        let callback : CLogCallback = { (line : UnsafePointer<Int8>?) -> Void in
            NSLog(String.init(cString: line!))
        }
        LogSetCallback(callback)
    }
    
    public func setup(url : String) {
        NSLog("setup")

        clear()
        
        // setup options
        var options : MessageRef = SharedMessageCreate()
        let FrameCallback : CFrameCallback = { (current : MediaFrameRef?, user : UnsafeMutableRawPointer?) -> Void in
            if (current == nil) {
                NSLog("FrameCallback: nil MediaFrameRef")
            } else {
                //NSLog("FrameCallback");
                let context : MediaOutContext = Unmanaged.fromOpaque(user!).takeUnretainedValue()
                if (current != nil) {
                    context.mMediaFrame = SharedObjectRetain(current)
                }
                
                DispatchQueue.main.async {
                    //NSLog("drawMediaFrame in main")
                    
                    if (context.mMediaFrame == nil) {
                        NSLog("nil MediaFrame")
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
        
        let PositionCallback : CPositionCallback = { (pos : Int64, user : UnsafeMutableRawPointer?) -> Void in
            NSLog("PositionCallback")
        }
        let OnPositionUpdate : PositionEventRef = PositionEventCreate(PositionCallback, nil)
        SharedMessagePutObject(options, "RenderPositionEvent", OnPositionUpdate)
        SharedObjectRelease(OnPositionUpdate)
        
        var media : MessageRef = SharedMessageCreate()
        SharedMessagePutString(media, "url", url)
        
        NSLog("MediaPlayerCreate");
        mHandle = MediaPlayerCreate(media, options)
        
        // release refs
        SharedObjectRelease(options)
        SharedObjectRelease(media)
    }
    
    public func prepare(us : Int64) {
        if (mHandle != nil) {
            NSLog("MediaPlayerPrepare");
            var options : MessageRef = SharedMessageCreate()
            SharedMessagePutInt64(options, "MediaTime", us)
            MediaPlayerPrepare(mHandle, options)
            SharedObjectRelease(options)
        }
    }
    
    public func startOrPause() {
        if (mHandle != nil) {
            let state = MediaPlayerGetState(mHandle)
            if (state == kStatePlaying) {
                NSLog("MediaPlayerPause");
                MediaPlayerPause(mHandle)
            } else if (state == kStateReady || state == kStateIdle) {
                NSLog("MediaPlayerStart");
                MediaPlayerStart(mHandle)
            } else {
                NSLog("MediaPlayer bad state")
            }
        }
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
            // FIXME: may block
            MediaPlayerRelease(mHandle)
            mHandle = nil
        }
    }
}
