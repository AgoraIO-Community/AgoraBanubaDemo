//
//  CustomVideoSource.swift
//  BanubaSdkApp
//
//  Created by Jonathan  Fotland on 8/3/20.
//  Copyright © 2020 Banuba. All rights reserved.
//

import UIKit
import AgoraRtcKit

/**
 A custom video source for the AgoraRtcEngine. This class conforms to the AgoraVideoSourceProtocol and is used to pass the AR pixel buffer as a video source of the Agora stream.
 */
class CustomVideoSource: NSObject, AgoraVideoSourceProtocol {
    var consumer: AgoraVideoFrameConsumer?
    var rotation: AgoraVideoRotation = .rotation180
    
    func shouldInitialize() -> Bool { return true }
    
    func shouldStart() { }
    
    func shouldStop() { }
    
    func shouldDispose() { }
    
    func bufferType() -> AgoraVideoBufferType {
        return .pixelBuffer
    }
    
    func captureType() -> AgoraVideoCaptureType {
        return .camera
    }
    
    func contentHint() -> AgoraVideoContentHint {
        return .motion
    }
    
    func sendBuffer(_ buffer: CVPixelBuffer, timestamp: TimeInterval) {
        let time = CMTime(seconds: timestamp, preferredTimescale: 1000)
        consumer?.consumePixelBuffer(buffer, withTimestamp: time, rotation: rotation)
    }
}
