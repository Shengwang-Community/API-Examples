//
//  SDKRenderViewModel.swift
//  APIExample-SwiftUI
//
//  Created by qinhui on 2024/8/14.
//

import Foundation

/**
    @class      SDKRenderViewModel（
    @abstract   This type has nothing to do with PIP and only simulates the implementation of rtc services for service reference and can be modified according to the service
 */
class SDKRenderViewModel: NSObject, ObservableObject {
    private var isJoined = false
    var sdkRenderRtc: SDKRenderRTC
    var configs: [String: Any]
    
    @Published var remoteRenderViews: [VideoView] = []
    
    private lazy var rtcConfig: AgoraRtcEngineConfig = {
       let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AppId
        config.areaCode = .global
        config.channelProfile = .liveBroadcasting
        return config
    }()

    private lazy var rtcEngine: AgoraRtcEngineKit = {
        let engine = AgoraRtcEngineKit.sharedEngine(with: rtcConfig, delegate: self)
        engine.setClientRole(.broadcaster)
        engine.enableAudio()
        engine.enableVideo()
        engine.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: CGSize(width: 960, height: 540),
                                                                           frameRate: .fps15,
                                                                           bitrate: AgoraVideoBitrateStandard,
                                                                           orientationMode: .fixedPortrait,
                                                                           mirrorMode: .auto))

        return engine
    }()
    
    init(configs: [String: Any]) {
        self.sdkRenderRtc = SDKRenderRTC()
        self.configs = configs
        super.init()
    }
    
    func setupRtcEngine(localView: VideoUIView) {
        guard let channelName = configs["channelName"] as? String else { return }
        let uid = UInt.random(in: 1..<100000)
        rtcEngine.setDefaultAudioRouteToSpeakerphone(true)
        
        sdkRenderRtc.setupRtcEngine(rtcEngine: rtcEngine)
        sdkRenderRtc.setLocalView(localView: localView)

        NetworkManager.shared.generateToken(channelName: channelName, success: { [weak self] token in
            guard let self = self else { return }
            
            let option = AgoraRtcChannelMediaOptions()
            option.publishCameraTrack = true
            option.publishMicrophoneTrack = true
            option.clientRoleType = .broadcaster
            self.rtcEngine.joinChannel(byToken: token, channelId: channelName, uid: uid, mediaOptions: option)
        })
    }
    
    func cleanRtc() {
        rtcEngine.disableAudio()
        rtcEngine.disableVideo()
        if isJoined {
            rtcEngine.stopPreview()
            rtcEngine.leaveChannel(nil)
        }
        AgoraRtcEngineKit.destroy()
    }
    
    func addRenderView(renderView: VideoView) {
        remoteRenderViews.append(renderView)
        
        sdkRenderRtc.addRemoteRenderView(renderView: renderView.videoView)
    }
    
    func removeRenderView(renderView: VideoView) {
        if let index = remoteRenderViews.firstIndex(where: { $0.videoView.uid == renderView.videoView.uid }) {
            remoteRenderViews.remove(at: index)
        }
        
        sdkRenderRtc.removeRemoteRenderView(renderView: renderView.videoView)
    }
}

extension SDKRenderViewModel: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        self.isJoined = true
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        let renderView = VideoView()
        renderView.videoView.uid = uid
        self.addRenderView(renderView: renderView)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        if let view = remoteRenderViews.first(where: { $0.videoView.uid == uid }) {
            self.removeRenderView(renderView: view)
        }
    }
}
