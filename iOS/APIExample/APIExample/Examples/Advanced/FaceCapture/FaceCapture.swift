//
//  JoinChannelVideo.swift
//  APIExample
//
//  Created by 张乾泽 on 2020/4/17.
//  Copyright © 2020 Agora Corp. All rights reserved.
//
import UIKit
import AGEVideoLayout
import AgoraRtcKit

class FaceCaptureEntry: UIViewController {
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var channelTextField: UITextField!
    let identifier = "FaceCapture"
    @IBOutlet var resolutionBtn: UIButton!
    @IBOutlet var fpsBtn: UIButton!
    @IBOutlet var orientationBtn: UIButton!
    var width: Int = 960, height: Int = 540, orientation: AgoraVideoOutputOrientationMode = .adaptative, fps = 15
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func getResolutionAction(width: Int, height: Int) -> UIAlertAction {
        return UIAlertAction(title: "\(width)x\(height)", style: .default, handler: {[unowned self] _ in
            self.width = width
            self.height = height
            self.resolutionBtn.setTitle("\(width)x\(height)", for: .normal)
        })
    }
    
    func getFpsAction(_ fps: Int) -> UIAlertAction {
        return UIAlertAction(title: "\(fps)fps", style: .default, handler: { [unowned self] _ in
            self.fps = fps
            self.fpsBtn.setTitle("\(fps)fps", for: .normal)
        })
    }
    
    func getOrientationAction(_ orientation: AgoraVideoOutputOrientationMode) -> UIAlertAction {
        return UIAlertAction(title: "\(orientation.description())", style: .default, handler: { [unowned self] _ in
            self.orientation = orientation
            self.orientationBtn.setTitle("\(orientation.description())", for: .normal)
        })
    }
    
    @IBAction func setResolution() {
        let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let alert = UIAlertController(title: "Set Resolution".localized,
                                      message: nil,
                                      preferredStyle: style)
        alert.addAction(getResolutionAction(width: 90, height: 90))
        alert.addAction(getResolutionAction(width: 160, height: 120))
        alert.addAction(getResolutionAction(width: 320, height: 240))
        alert.addAction(getResolutionAction(width: 960, height: 540))
        alert.addAction(getResolutionAction(width: 1280, height: 720))
        alert.addCancelAction()
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func setFps() {
        let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let alert = UIAlertController(title: "Set Fps".localized,
                                      message: nil,
                                      preferredStyle: style)
        alert.addAction(getFpsAction(10))
        alert.addAction(getFpsAction(15))
        alert.addAction(getFpsAction(24))
        alert.addAction(getFpsAction(30))
        alert.addAction(getFpsAction(60))
        alert.addCancelAction()
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func setOrientation() {
        let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let alert = UIAlertController(title: "Set Orientation".localized,
                                      message: nil,
                                      preferredStyle: style)
        alert.addAction(getOrientationAction(.adaptative))
        alert.addAction(getOrientationAction(.fixedLandscape))
        alert.addAction(getOrientationAction(.fixedPortrait))
        alert.addCancelAction()
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func doJoinPressed(sender: UIButton) {
        guard let channelName = channelTextField.text else { return }
        // resign channel text field
        channelTextField.resignFirstResponder()
        
        let storyBoard: UIStoryboard = UIStoryboard(name: identifier, bundle: nil)
        // create new view controller every time to ensure we get a clean vc
        guard let newViewController = storyBoard.instantiateViewController(withIdentifier: identifier) as? BaseViewController else {return}
        newViewController.title = channelName
        newViewController.configs = ["channelName": channelName,
                                     "resolution": CGSize(width: width, height: height),
                                     "fps": fps,
                                     "orientation": orientation]
        navigationController?.pushViewController(newViewController, animated: true)
    }
}

class FaceCaptureMain: BaseViewController {
    var localVideo = Bundle.loadVideoView(type: .local, audioOnly: false)
    
    @IBOutlet weak var container: AGEVideoContainer!
    var agoraKit: AgoraRtcEngineKit!
    
    // indicate if current instance has joined channel
    var isJoined: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // layout render view
        localVideo.setPlaceholder(text: "Local Host".localized)
        container.layoutStream(views: [localVideo])
        
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
        guard let channelName = configs["channelName"] as? String,
            let resolution = configs["resolution"] as? CGSize,
            let fps = configs["fps"] as? Int,
            let orientation = configs["orientation"] as? AgoraVideoOutputOrientationMode else {return}
        
        // make myself a broadcaster
        agoraKit.setClientRole(GlobalSettings.shared.getUserRole())
        // enable video module and set up video encoding configs
        agoraKit.enableVideo()
        agoraKit.enableAudio()
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: resolution,
                frameRate: AgoraVideoFrameRate(rawValue: fps) ?? .fps15,
                bitrate: AgoraVideoBitrateStandard,
                orientationMode: orientation, mirrorMode: .auto))
        
        if (KeyCenter.FaceCaptureLicense ?? "").isEmpty {
            showAlert(message: "Please contact Agora customer service to obtain a face capture certificate".localized)
        } else {
            // enable face capture
            agoraKit.enableExtension(withVendor: "agora_video_filters_face_capture",
                                     extension: "face_capture",
                                     enabled: true,
                                     sourceType: .primaryCamera)
            
            agoraKit.setExtensionPropertyWithVendor("agora_video_filters_face_capture",
                                                    extension: "face_capture",
                                                    key: "authentication_information",
                                                    value: "{\"company_id\":\"agoraTest\"," +
                                                    "\"license\":\"" + (KeyCenter.FaceCaptureLicense ?? "") + "\"}",
                                                    sourceType: .primaryCamera)
            
            agoraKit.enableExtension(withVendor: "agora_filters_lip_sync",
                                     extension: "lip_sync",
                                     enabled: true,
                                     sourceType: .speechDriven)
            agoraKit.setExtensionPropertyWithVendor("agora_filters_lip_sync",
                                                    extension: "lip_sync",
                                                    key: "parameters",
                                                    value: "{\"company_id\":\"agoraTest\",  \"license\":\"abc\", \"open_agc\":true}",
                                                    sourceType: .speechDriven)
            
            agoraKit.setVideoFrameDelegate(self)
            agoraKit.setFaceInfoDelegate(self)
        }

        // set up local video to render your local camera preview
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        // the view to be binded
        videoCanvas.view = localVideo.videoView
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
        // you have to call startPreview to see local video
        agoraKit.startPreview()
        
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
        NetworkManager.shared.generateToken(channelName: channelName, success: { token in
            let result = self.agoraKit.joinChannel(byToken: token, channelId: channelName, uid: 0, mediaOptions: option)
            if result != 0 {
                // Usually happens with invalid parameters
                // Error code description can be found at:
                // en: https://api-ref.agora.io/en/video-sdk/ios/4.x/documentation/agorartckit/agoraerrorcode
                // cn: https://doc.shengwang.cn/api-ref/rtc/ios/error-code
                self.showAlert(title: "Error", message: "joinChannel call failed: \(result), please check your params")
            }
        })
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        agoraKit.disableAudio()
        agoraKit.disableVideo()
        if isJoined {
            agoraKit.stopPreview()
            agoraKit.leaveChannel { (stats) -> Void in
                LogUtils.log(message: "left channel, duration: \(stats.duration)", level: .info)
            }
        }
    }
}

extension FaceCaptureMain: AgoraFaceInfoDelegate {
    func onFaceInfo(_ outFaceInfo: String) -> Bool {
        localVideo.statsInfo?.updateMetaInfo(data: outFaceInfo)
        return true
    }
}

extension FaceCaptureMain: AgoraVideoFrameDelegate {
    func onCapture(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool {
        let info = videoFrame.metaInfo["KEY_FACE_CAPTURE"] as? String
        localVideo.statsInfo?.updateMetaInfo(data: info)
        LogUtils.log(message: info ?? "", level: .info)
        return true
    }
    func getVideoFrameProcessMode() -> AgoraVideoFrameProcessMode {
        .readWrite
    }
    func getObservedFramePosition() -> AgoraVideoFramePosition {
        .postCapture
    }
}

/// agora rtc engine delegate events
extension FaceCaptureMain: AgoraRtcEngineDelegate {
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
        self.showAlert(title: "Error", message: "Error \(errorCode.description) occur")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        self.isJoined = true
        LogUtils.log(message: "Join \(channel) with uid \(uid) elapsed \(elapsed)ms", level: .info)
    }
    
    /// callback when a remote user is joinning the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        LogUtils.log(message: "remote user join: \(uid) \(elapsed)ms", level: .info)
    }
    
    /// callback when a remote user is leaving the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param reason reason why this user left, note this event may be triggered when the remote user
    /// become an audience in live broadcasting profile
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        LogUtils.log(message: "remote user left: \(uid) reason \(reason)", level: .info)
        
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
    
    /// Reports the statistics of the current call. The SDK triggers this callback once every two seconds after the user joins the channel.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
        localVideo.statsInfo?.updateChannelStats(stats)
    }
    
    /// Reports the statistics of the uploading local audio streams once every two seconds.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, localAudioStats stats: AgoraRtcLocalAudioStats) {
        localVideo.statsInfo?.updateLocalAudioStats(stats)
    }
}
