//
//  AgoraCode.swift
//  OpenLive
//
//  Created by CavanSu on 2019/9/16.
//  Copyright © 2019 Agora. All rights reserved.
//

import AgoraRtcKit

extension AgoraErrorCode {
    var description: String {
        var text: String
        switch self {
        case .joinChannelRejected:  text = "join channel rejected"
        case .leaveChannelRejected: text = "leave channel rejected"
        case .invalidAppId:         text = "invalid app id"
        case .invalidToken:         text = "invalid token"
        case .invalidChannelId:     text = "invalid channel id"
        default:                    text = "\(self.rawValue)"
        }
        return text
    }
}

extension AgoraWarningCode {
    var description: String {
        var text: String
        switch self {
        case .invalidView: text = "invalid view"
        default:           text = "\(self.rawValue)"
        }
        return text
    }
}

extension AgoraNetworkQuality {
    func description() -> String {
        switch self {
        case .excellent:   return "excel"
        case .good:        return "good"
        case .poor:        return "poor"
        case .bad:         return "bad"
        case .vBad:        return "vBad"
        case .down:        return "down"
        case .unknown:     return "NA"
        default:           return "NA"
        }
    }
}

extension AgoraVideoOutputOrientationMode {
    func description() -> String {
        switch self {
        case .fixedPortrait: return "fixed portrait".localized
        case .fixedLandscape: return "fixed landscape".localized
        case .adaptative: return "adaptive".localized
        default: return "\(self.rawValue)"
        }
    }
}

extension AgoraClientRole {
    func description() -> String {
        switch self {
        case .broadcaster: return "Broadcaster".localized
        case .audience: return "Audience".localized
        default:
            return "\(self.rawValue)"
        }
    }
}

extension AgoraAudioProfile {
    func description() -> String {
        switch self {
        case .default: return "Default".localized
        case .musicStandard: return "Music Standard".localized
        case .musicStandardStereo: return "Music Standard Stereo".localized
        case .musicHighQuality: return "Music High Quality".localized
        case .musicHighQualityStereo: return "Music High Quality Stereo".localized
        case .speechStandard: return "Speech Standard".localized
        default:
            return "\(self.rawValue)"
        }
    }
    static func allValues() -> [AgoraAudioProfile] {
        return [.default, .speechStandard, .musicStandard, .musicStandardStereo, .musicHighQuality, .musicHighQualityStereo]
    }
}

extension AgoraAudioScenario {
    func description() -> String {
        switch self {
        case .default: return "Default".localized
        case .gameStreaming: return "Game Streaming".localized
        default:
            return "\(self.rawValue)"
        }
    }
    
    static func allValues() -> [AgoraAudioScenario] {
        return [.default, .gameStreaming]
    }
}

extension AgoraEncryptionMode {
    func description() -> String {
        switch self {
        case .AES128GCM: return "AES128GCM"
        case .AES256GCM: return "AES256GCM"
        default:
            return "\(self.rawValue)"
        }
    }
    
    static func allValues() -> [AgoraEncryptionMode] {
        return [.AES128GCM, .AES256GCM]
    }
}

extension AgoraVoiceBeautifierPreset {
    func description() -> String {
        switch self {
        case .presetOff: return "Off".localized
        case .presetChatBeautifierFresh: return "FemaleFresh".localized
        case .presetChatBeautifierMagnetic: return "MaleMagnetic".localized
        case .presetChatBeautifierVitality: return "FemaleVitality".localized
        case .timbreTransformationVigorous: return "Vigorous".localized
        case .timbreTransformationDeep: return "Deep".localized
        case .timbreTransformationMellow: return "Mellow".localized
        case .timbreTransformationFalsetto: return "Falsetto".localized
        case .timbreTransformationFull: return "Full".localized
        case .timbreTransformationClear: return "Clear".localized
        case .timbreTransformationResounding: return "Resounding".localized
        case .timbreTransformatRinging: return "Ringing".localized
        default: return "\(self.rawValue)"
        }
    }
}

extension AgoraAudioReverbPreset {
    func description() -> String {
        switch self {
        case .off: return "Off".localized
        case .fxUncle: return "FxUncle".localized
        case .fxSister: return "FxSister".localized
        case .fxPopular: return "Pop".localized
        case .fxRNB: return "R&B".localized
        case .fxVocalConcert: return "Vocal Concert".localized
        case .fxKTV: return "KTV".localized
        case .fxStudio: return "Studio".localized
        case .fxPhonograph: return "Phonograph".localized
        default: return "\(self.rawValue)"
        }
    }
}

extension AgoraAudioEffectPreset {
    func description() -> String {
        switch self {
        case .off: return "Off".localized
        case .voiceChangerEffectUncle: return "FxUncle".localized
        case .voiceChangerEffectOldMan: return "Old Man".localized
        case .voiceChangerEffectBoy: return "Baby Boy".localized
        case .voiceChangerEffectSister: return "FxSister".localized
        case .voiceChangerEffectGirl: return "Baby Girl".localized
        case .voiceChangerEffectPigKin: return "ZhuBaJie".localized
        case .voiceChangerEffectHulk: return "Hulk".localized
        case .styleTransformationRnb: return "R&B".localized
        case .styleTransformationPopular: return "Pop".localized
        case .roomAcousticsKTV: return "KTV".localized
        case .roomAcousVocalConcer: return "Vocal Concert".localized
        case .roomAcousStudio: return "Studio".localized
        case .roomAcousPhonograph: return "Phonograph".localized
        case .roomAcousVirtualStereo: return "Virtual Stereo".localized
        case .roomAcousSpatial: return "Spacial".localized
        case .roomAcousEthereal: return "Ethereal".localized
        case .roomAcous3DVoice: return "3D Voice".localized
        case .pitchCorrection: return "Pitch Correction".localized
        default: return "\(self.rawValue)"
        }
    }
}

extension AgoraAudioEqualizationBandFrequency {
    func description() -> String {
        switch self {
        case .band31: return "31Hz"
        case .band62: return "62Hz"
        case .band125: return "125Hz"
        case .band250: return "250Hz"
        case .band500: return "500Hz"
        case .band1K: return "1kHz"
        case .band2K: return "2kHz"
        case .band4K: return "4kHz"
        case .band8K: return "8kHz"
        case .band16K: return "16kHz"
        default: return "\(self.rawValue)"
        }
    }
}

extension AgoraAudioReverbType {
    func description() -> String {
        switch self {
        case .dryLevel: return "Dry Level".localized
        case .wetLevel: return "Wet Level".localized
        case .roomSize: return "Room Size".localized
        case .wetDelay: return "Wet Delay".localized
        case .strength: return "Strength".localized
        @unknown default: return "\(self.rawValue)"
        }
    }
}

extension AUDIO_AINS_MODE {
    func description() -> String {
        switch self {
        case .AINS_MODE_AGGRESSIVE: return "AGGRESSIVE".localized
        case .AINS_MODE_BALANCED: return "BALANCED".localized
        case .AINS_MODE_ULTRALOWLATENCY: return "ULTRALOWLATENCY".localized
        @unknown default: return "\(self.rawValue)"
        }
    }
}

extension AgoraVoiceAITunerType {
    func description() -> String {
        switch self {
        case .matureMale: return "Mature Male Voice".localized
        case .freshMale: return "Fresh Male Voice".localized
        case .elegantFemale: return "Elegant Female Voice".localized
        case .sweetFemale: return "Sweet Female Voice".localized
        case .warmMaleSinging: return "Warm Male Singing Voice".localized
        case .gentleFemaleSinging: return "Gentle Female Singing Voice".localized
        case .huskyMaleSinging: return "Husky Male Singing Voice".localized
        case .warmElegantFemaleSinging: return "Warm Elegant Female Singing Voice".localized
        case .powerfulMaleSinging: return "Powerful Male Singing Voice".localized
        case .dreamyFemaleSinging: return "Dreamy Female Singing Voice".localized
        @unknown default: return "\(self.rawValue)"
        }
    }
}

extension AgoraVoiceConversionPreset {
    func description() -> String {
        switch self {
        case .off: return "Off".localized
        case .neutral: return "Neutral".localized
        case .sweet: return "Sweet".localized
        case .changerSolid: return "Solid".localized
        case .changerBass: return "Bass".localized
        default: return "\(self.rawValue)"
        }
    }
}

extension UIAlertController {
    func addCancelAction() {
        self.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
    }
}

extension UIApplication {
    /// The top most view controller
    static var topMostViewController: UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController?.visibleViewController
    }
}

extension UIViewController {
    /// The visible view controller from a given view controller
    var visibleViewController: UIViewController? {
        if let navigationController = self as? UINavigationController {
            return navigationController.topViewController?.visibleViewController
        } else if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.visibleViewController
        } else if let presentedViewController = presentedViewController {
            return presentedViewController.visibleViewController
        } else {
            return self
        }
    }
}

extension OutputStream {

    /// Write `String` to `OutputStream`
    ///
    /// - parameter string:                The `String` to write.
    /// - parameter encoding:              The `String.Encoding` to use when writing the string. This will default to `.utf8`.
    /// - parameter allowLossyConversion:  Whether to permit lossy conversion when writing the string. Defaults to `false`.
    ///
    /// - returns:                         Return total number of bytes written upon success. Return `-1` upon failure.
    func write(_ string: String, encoding: String.Encoding = .utf8, allowLossyConversion: Bool = false) -> Int {

        if let data = string.data(using: encoding, allowLossyConversion: allowLossyConversion) {
            let bytes = data.withUnsafeBytes({ $0 })
            if let address = bytes.baseAddress {
                write(address, maxLength: bytes.count)
            }
        }
        return -1
    }

}

extension Date {
   func getFormattedDate(format: String) -> String {
        let dateformat = DateFormatter()
        dateformat.dateFormat = format
        return dateformat.string(from: self)
    }
}


extension AgoraFocalLengthInfo {
    var value: [String: AgoraFocalLength] {
        let title = cameraDirection == 1 ? "Front camera".localized + " - " : "Rear camera".localized + " - "
        switch focalLengthType {
        case .default: return [title + "Default".localized: focalLengthType]
        case .wide: return [title + "Wide".localized: focalLengthType]
        case .ultraWide: return [title + "Length Wide".localized: focalLengthType]
        case .telephoto: return [title + "Telephoto".localized: focalLengthType]
        @unknown default: return [title + "Default".localized: focalLengthType]
        }
    }
}

extension AgoraApplicationScenarioType {
    func description() -> String {
        switch self {
        case .applicationGeneralScenario: return "General".localized
        case .applicationMeetingScenario: return "Meeting".localized
        case .application1V1Scenario: return "1v1".localized
        case .applicationLiveShowScenario: return "Live Show".localized
        @unknown default: return ""
        }
    }
}

extension AgoraVideoModulePosition {
    func description() -> String {
        switch self {
        case .postCapture: return "Post Capture".localized
        case .preRenderer: return "PreRenderer".localized
        case .preEncoder: return "PreEncoder".localized
        case .postCaptureOrigin: return "Post Capture Origin".localized
        @unknown default: return ""
        }
    }
}
