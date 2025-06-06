//
//  JoinChannelVideoRTC.swift
//  APIExample-SwiftUI
//
//  Created by zhaoyongqiang on 2024/3/19.
//

import AgoraRtcKit
import SwiftUI

class MutliCameraRTC: NSObject, ObservableObject {
    private var agoraKit: AgoraRtcEngineKit!
    private var isJoined: Bool = false
    private var channelName: String?
    private lazy var uid: UInt = UInt.random(in: 1...9999)
    private lazy var mutliCameraUid: UInt = UInt.random(in: 10000...9999999)
    private var isOpenCamera: Bool = false
    
    private var localView: VideoUIView?
    private var remoteView: VideoUIView?
    
    
    func setupRTC(configs: [String: Any],
                  localView: VideoUIView,
                  remoteView: VideoUIView) {
        self.localView = localView
        self.remoteView = remoteView
        remoteView.setPlaceholder(text: "Second camera".localized)
        // set up agora instance when view loaded
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AppId
        config.areaCode = GlobalSettings.shared.area
        config.channelProfile = .liveBroadcasting
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        // Configuring Privatization Parameters
        Util.configPrivatization(agoraKit: agoraKit)
        
        agoraKit.setLogFile(LogUtils.sdkLogPath())
        // get channel name from configs
        guard let channelName = configs["channelName"] as? String else {return}
        self.channelName = channelName
        let fps = GlobalSettings.shared.getFps()
        let resolution = GlobalSettings.shared.getResolution()
        let orientation = GlobalSettings.shared.getOrientation()
        
        // make myself a broadcaster
        agoraKit.setClientRole(GlobalSettings.shared.getUserRole())
        // enable video module and set up video encoding configs
        agoraKit.enableVideo()
        agoraKit.enableAudio()
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: resolution,
                                                                             frameRate: fps,
                                                                             bitrate: AgoraVideoBitrateStandard,
                                                                             orientationMode: orientation, mirrorMode: .auto))
        
        // open Multi Camera
        let capturerConfig = AgoraCameraCapturerConfiguration()
        capturerConfig.cameraDirection = .rear
        agoraKit.enableMultiCamera(true, config: capturerConfig)
        
        setupCanvasView(view: localView.videoView)
        
        // Set audio route to speaker
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        
        // start joining channel
        // 1. Users can only see each other after they join the
        // same channel successfully using the same app id.
        // 2. If app certificate is turned on at dashboard, token is needed
        // when joining channel. The channel name and uid used to calculate
        // the token has to match the ones used for channel join
        let option = AgoraRtcChannelMediaOptions()
        option.publishCameraTrack = GlobalSettings.shared.getUserRole() == .broadcaster
        option.publishMicrophoneTrack = GlobalSettings.shared.getUserRole() == .broadcaster
        option.clientRoleType = GlobalSettings.shared.getUserRole()
        NetworkManager.shared.generateToken(channelName: channelName, uid: uid, success: { token in
            let result = self.agoraKit.joinChannel(byToken: token, channelId: channelName, uid: self.uid, mediaOptions: option)
            if result != 0 {
                // Usually happens with invalid parameters
                // Error code description can be found at:
                // en: https://api-ref.agora.io/en/video-sdk/ios/4.x/documentation/agorartckit/agoraerrorcode
                // cn: https://doc.shengwang.cn/api-ref/rtc/ios/error-code
                LogUtils.log(message: "joinChannel call failed: \(result), please check your params", level: .error)
            }
        })
    }
    
    func onTapBackCameraButton(_ isOpenCamera: Bool) {
        self.isOpenCamera = isOpenCamera
        guard let channelName = self.channelName else {return}
        let connection = AgoraRtcConnection()
        connection.channelId = channelName
        connection.localUid = mutliCameraUid
        if isOpenCamera {
            let videoCanvas = AgoraRtcVideoCanvas()
            videoCanvas.uid = mutliCameraUid
            videoCanvas.view = remoteView?.videoView
            videoCanvas.renderMode = .hidden
            videoCanvas.sourceType = .cameraSecondary
            videoCanvas.mirrorMode = .disabled
            agoraKit.setupLocalVideo(videoCanvas)
            
            let cameraConfig = AgoraCameraCapturerConfiguration()
            cameraConfig.cameraDirection = .rear
            cameraConfig.dimensions = remoteView?.videoView.frame.size ?? .zero
            agoraKit.enableMultiCamera(true, config: cameraConfig)
            agoraKit.startCameraCapture(.cameraSecondary, config: cameraConfig)
            
            let option = AgoraRtcChannelMediaOptions()
            option.publishSecondaryCameraTrack = true
            option.publishMicrophoneTrack = true
            option.clientRoleType = .broadcaster
            option.autoSubscribeAudio = false
            option.autoSubscribeVideo = false
            NetworkManager.shared.generateToken(channelName: channelName, uid: mutliCameraUid) { token in
                self.agoraKit.joinChannelEx(byToken: token, connection: connection, delegate: self, mediaOptions: option, joinSuccess: nil)
                self.agoraKit.muteRemoteAudioStream(self.mutliCameraUid, mute: true)
                self.agoraKit.muteRemoteVideoStream(self.mutliCameraUid, mute: true)
            }
        } else {
            let videoCanvas = AgoraRtcVideoCanvas()
            videoCanvas.uid = mutliCameraUid
            videoCanvas.view = nil
            videoCanvas.renderMode = .hidden
            videoCanvas.sourceType = .cameraSecondary
            agoraKit.setupLocalVideo(videoCanvas)
            agoraKit.stopCameraCapture(.cameraSecondary)
            agoraKit.leaveChannelEx(connection, leaveChannelBlock: nil)
        }
    }
    
    private func setupCanvasView(view: UIView?) {
        // set up local video to render your local camera preview
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        // the view to be binded
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
        // you have to call startPreview to see local video
        agoraKit.startPreview()
    }
    
    func onDestory() {
        agoraKit.disableAudio()
        agoraKit.disableVideo()
        if isJoined {
            agoraKit.stopPreview()
            agoraKit.leaveChannel { (stats) -> Void in
                LogUtils.log(message: "left channel, duration: \(stats.duration)", level: .info)
            }
            if isOpenCamera {
                guard let channelName = channelName else {return}
                let connection = AgoraRtcConnection()
                connection.channelId = channelName
                connection.localUid = mutliCameraUid
                agoraKit.stopCameraCapture(.cameraSecondary)
                agoraKit.leaveChannelEx(connection, leaveChannelBlock: nil)
            }
        }
        AgoraRtcEngineKit.destroy()
    }
}

// agora rtc engine delegate events
extension MutliCameraRTC: AgoraRtcEngineDelegate {
    /// callback when warning occured for agora sdk, warning can usually be ignored, still it's nice to check out
    /// what is happening
    /// Warning code description can be found at:
    /// en: https://api-ref.agora.io/en/voice-sdk/ios/3.x/Constants/AgoraWarningCode.html
    /// cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraWarningCode.html
    /// @param warningCode warning code of the problem
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        LogUtils.log(message: "warning: \(warningCode.description)", level: .warning)
    }
    
    /// callback when error occured for agora sdk, you are recommended to display the error descriptions on demand
    /// to let user know something wrong is happening
    /// Error code description can be found at:
    /// en: https://api-ref.agora.io/en/video-sdk/ios/4.x/documentation/agorartckit/agoraerrorcode
    /// cn: https://doc.shengwang.cn/api-ref/rtc/ios/error-code
    /// @param errorCode error code of the problem
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        LogUtils.log(message: "error: \(errorCode)", level: .error)
        //        self.showAlert(title: "Error", message: "Error \(errorCode.description) occur")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        self.isJoined = true
        localView?.uid = uid
        LogUtils.log(message: "Join \(channel) with uid \(uid) elapsed \(elapsed)ms", level: .info)
    }
    
    /// callback when a remote user is joinning the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        LogUtils.log(message: "remote user join: \(uid) \(elapsed)ms", level: .info)
        remoteView?.uid = uid
    }
    
    /// callback when a remote user is leaving the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param reason reason why this user left, note this event may be triggered when the remote user
    /// become an audience in live broadcasting profile
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        LogUtils.log(message: "remote user left: \(uid) reason \(reason)", level: .info)
        remoteView?.uid = 0
        // to unlink your view from sdk, so that your view reference will be released
        // note the video will stay at its last frame, to completely remove it
        // you will need to remove the EAGL sublayer from your binded view
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        // the view to be binded
        videoCanvas.view = nil
        videoCanvas.renderMode = .hidden
        agoraKit.setupRemoteVideo(videoCanvas)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        LogUtils.log(message: "Connection state changed: \(state) \(reason)", level: .info)
    }
    
    /// Reports the statistics of the current call. The SDK triggers this callback once every two seconds after the user joins the channel.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
        localView?.statsInfo?.updateChannelStats(stats)
    }
    
    /// Reports the statistics of the uploading local audio streams once every two seconds.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, localAudioStats stats: AgoraRtcLocalAudioStats) {
        localView?.statsInfo?.updateLocalAudioStats(stats)
    }
}
