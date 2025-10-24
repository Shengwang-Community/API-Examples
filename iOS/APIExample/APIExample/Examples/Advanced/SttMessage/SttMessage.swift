//
//  VoiceAITranscript.swift
//  APIExample
//
//  Created by qinhui on 2025/10/21.
//  Copyright © 2025 Agora Corp. All rights reserved.
//

import Foundation
import AgoraRtcKit
import UIKit
import SnapKit

enum TranscriptMode: String, CaseIterable {
    case syncTranslate = "转写翻译异步模式（同步翻译）"
    case asyncTranslate = "转写翻译异步模式（异步翻译）"
}

enum TranslationMode: String, CaseIterable {
    case zhToEn = "中译英"
    case enToZh = "英译中"
}

class SttMessageEntry: UIViewController {
    @IBOutlet weak var channelTextField: UITextField!
    @IBOutlet weak var transcriptTypeButton: UIButton!
    @IBOutlet weak var translationTypeButton: UIButton!
    private var transcriptMode: TranscriptMode = .asyncTranslate
    private var translationMode: TranslationMode = .zhToEn
    
    override func viewDidLoad() {
        super.viewDidLoad()
        transcriptTypeButton.setTitle(transcriptMode.rawValue, for: .normal)
        translationTypeButton.setTitle(translationMode.rawValue, for: .normal)
    }
    
    @IBAction func start(_ sender: Any) {
        guard let channelName = channelTextField.text else { return }
        let vc = SttMessageViewController()
        vc.configs = ["channelName": channelName,
                      "transcriptMode": transcriptMode,
                      "translationMode": translationMode]
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func transcriptTypeButtonAction(_ sender: Any) {
        showModeSelectionAlert(for: .transcript)
    }
    
    @IBAction func translationTypeButtonAction(_ sender: Any) {
        showModeSelectionAlert(for: .translation)
    }
    
    private enum AlertType {
        case transcript
        case translation
    }
    
    private func showModeSelectionAlert(for type: AlertType) {
        let alertVC = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        switch type {
        case .transcript:
            addTranscriptModeActions(to: alertVC)
            
        case .translation:
            addTranslationModeActions(to: alertVC)
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        alertVC.addAction(cancelAction)
        
        present(alertVC, animated: true)
    }
    
    // 添加转写模式选项
    private func addTranscriptModeActions(to alertVC: UIAlertController) {
        let allCases = TranscriptMode.allCases
        for mode in allCases {
            let action = UIAlertAction(title: mode.rawValue, style: .default) { [weak self] _ in
                self?.transcriptMode = mode
                self?.transcriptTypeButton.setTitle(mode.rawValue, for: .normal)
            }
            alertVC.addAction(action)
        }
    }
    
    // 添加翻译模式选项
    private func addTranslationModeActions(to alertVC: UIAlertController) {
        let allCases = TranslationMode.allCases
        for mode in allCases {
            let action = UIAlertAction(title: mode.rawValue, style: .default) { [weak self] _ in
                self?.translationMode = mode
                self?.translationTypeButton.setTitle(mode.rawValue, for: .normal)
            }
            alertVC.addAction(action)
        }
    }
}

class SttMessageViewController: BaseViewController {
    private let baseUrl: String = "https://staging-toolbox-convoai-cn.bj2.agoralab.co"
    private var _agoraKit: AgoraRtcEngineKit?
    private lazy var localUid: UInt = UInt.random(in: 1...99999)
    private lazy var remoteUid: UInt = UInt.random(in: 1...99999)
    private var channelName = ""
    private var transcriptMode: TranscriptMode = .asyncTranslate
    private var translationMode: TranslationMode = .zhToEn
    
    var agoraKit: AgoraRtcEngineKit {
        if let engine = _agoraKit {
            return engine
        }
        
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AppId
        config.areaCode = GlobalSettings.shared.area
        config.channelProfile = .liveBroadcasting
        let engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        _agoraKit = engine
        
        return engine
    }
    
    // STT相关
    private let sttRenderer = SttMessageRenderer()
    private var sentences: [SttSentence] = []
    private var showTranslation = true
    private var sttResponseModel: STTResponseModel? = nil
    
    // UI组件
    private lazy var headerView: UIView = {
        let view = UIView()
        // Material Design primaryContainer 颜色
        view.backgroundColor = UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 1.0)
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "实时字幕"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        // Material Design onPrimaryContainer 颜色
        label.textColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        return label
    }()
    
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.text = "0 条"
        label.font = UIFont.systemFont(ofSize: 12)
        // Material Design onPrimaryContainer 颜色
        label.textColor = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        // Material Design surfaceVariant 颜色
        tableView.backgroundColor = UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1.0)
        tableView.separatorStyle = .none
        tableView.layer.cornerRadius = 12
        tableView.register(SentenceTableViewCell.self, forCellReuseIdentifier: "SentenceCell")
        return tableView
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "等待语音输入..."
        label.font = UIFont.systemFont(ofSize: 14)
        // Material Design onSurfaceVariant 颜色
        label.textColor = UIColor(red: 0.46, green: 0.46, blue: 0.51, alpha: 1.0)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAgent()
        agoraKit.leaveChannel()
        AgoraRtcEngineKit.destroy()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        guard let channelName = configs["channelName"] as? String,
              let transcriptMode = configs["transcriptMode"] as? TranscriptMode,
              let translationMode = configs["translationMode"] as? TranslationMode else { return }
        
        self.channelName = channelName
        self.transcriptMode = transcriptMode
        self.translationMode = translationMode
        
        //STTRenderer
        sttRenderer.processingMode = transcriptMode == .asyncTranslate ? .async : .sync
        sttRenderer.delegate = self
        
        //RTC
        let config = AgoraDataStreamMsgHandlerConfig()
        config.enableSttParser = true
        config.sttUid = remoteUid
        agoraKit.registerDataStreamMsgHandler(self, config: config)
        
        // make myself a broadcaster
        agoraKit.setClientRole(.broadcaster)
        
        // disable video module
        agoraKit.disableVideo()
        agoraKit.enableAudio()
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        
        let option = AgoraRtcChannelMediaOptions()
        option.publishCameraTrack = false
        option.publishMicrophoneTrack = true
        option.autoSubscribeAudio = true
        option.autoSubscribeVideo = false
        option.clientRoleType = GlobalSettings.shared.getUserRole()
        NetworkManager.shared.generateToken(channelName: channelName, success: { [weak self] token in
            guard let self = self else { return }
            self.startAgent()
            self.agoraKit.setParameters("{\"rtc.log_external_input\": true}")
            let result = self.agoraKit.joinChannel(byToken: token, channelId: channelName, uid: localUid, mediaOptions: option)
            if result != 0 {
                // Usually happens with invalid parameters
                // Error code description can be found at:
                // en: https://api-ref.agora.io/en/video-sdk/ios/4.x/documentation/agorartckit/agoraerrorcode
                // cn: https://doc.shengwang.cn/api-ref/rtc/ios/error-code
                self.showAlert(title: "Error", message: "joinChannel call failed: \(result), please check your params")
            }
        })
    }
    
    private func setupUI() {
        view.backgroundColor = .white

        view.addSubview(headerView)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(countLabel)
        
        // 使用SnapKit设置约束
        headerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(50)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }
        
        countLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
        }
        
        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
        }
        
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        let isEmpty = sentences.isEmpty
        emptyLabel.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
    
    private func updateSentences(_ newSentences: [SttSentence]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sentences = newSentences
            self.countLabel.text = "\(newSentences.count) 条"
            self.updateEmptyState()
            self.tableView.reloadData()
            
            // 自动滚动到底部
            if !newSentences.isEmpty {
                let indexPath = IndexPath(row: newSentences.count - 1, section: 0)
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    func startAgent() {
        let path = "/stt/v1/start"
        let url = "\(baseUrl)\(path)"
        var params: [String: Any] = [:]
        if self.translationMode == .enToZh {
            params = [
                "app_id": KeyCenter.AppId,
                "stt_body": [
                    "languages": [
                        "en-US",
                    ],
                    "name": "\(channelName)",
                    "maxIdleTime": 50,
                    "rtcConfig": [
                        "channelName": "\(channelName)",
                        "pubBotUid": "\(remoteUid)"
                    ],
                    "translateConfig": [
                        "languages": [
                          [
                            "source": "en-US",
                            "target": [
                                "zh-CN"
                            ]
                          ]
                        ]
                    ]
                ]
            ]
        } else {
            params = [
                "app_id": KeyCenter.AppId,
                "stt_body": [
                    "languages": [
                        "zh-CN",
                    ],
                    "name": "\(channelName)",
                    "maxIdleTime": 50,
                    "rtcConfig": [
                        "channelName": "\(channelName)",
                        "pubBotUid": "\(remoteUid)"
                    ],
                    "translateConfig": [
                        "languages": [
                          [
                            "source": "zh-CN",
                            "target": [
                                "en-US"
                            ]
                          ]
                        ]
                    ]
                ]
            ]
        }
        
        NetworkManager.shared.postRequest(urlString: url, params: params) { response in
            print(response)
            if let code = response["code"] as? Int, code != 0 {
                let msg = response["msg"] as? String ?? "Unknown error"
                print("request error, code: \(code), msg: \(msg)")
                return
            }
            
            guard let data = response["data"] else {
                print("request error, Missing data")
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let decoded = try JSONDecoder().decode(STTResponseModel.self, from: jsonData)
                self.sttResponseModel = decoded
            } catch {
                print("Json serialization failed")
            }
        } failure: { msg in
            print(msg)
        }
    }
    
    func stopAgent() {
        guard let agentId = sttResponseModel?.agentId else {
            print("Agent is not started")
            return
        }
        let path = "/stt/v1/stop"
        let url = "\(baseUrl)\(path)"
        let params: [String: Any] = [
            "app_id": KeyCenter.AppId,
            "agent_id": agentId
        ]
        NetworkManager.shared.postRequest(urlString: url, params: params, success: nil, failure: nil)
    }
}

extension SttMessageViewController: SttMessageRendererDelegate {
//    func onDebugLog(_ log: String) {
//        self.agoraKit.writeLog(.info, content: log)
//    }
}

extension SttMessageViewController: AgoraDataStreamMsgHandlerDelegate {
    func onSttMessage(channel: String, content sttmessage: AgoraSttMessage) {
//        self.agoraKit.writeLog(.info, content: "~~~~~~~~~\(sttmessage)")
        if #available(iOS 15.0, *) {
            print("\(Date().formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3))))~~~~~\(sttmessage)")
        } else {
            // Fallback on earlier versions
        }
        let updatedSentences = sttRenderer.processMessage(sttmessage)
        updateSentences(updatedSentences)
    }
}

extension SttMessageViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("didJoinedOfUid: \(uid)")
    }
}

extension SttMessageViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sentences.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SentenceCell", for: indexPath) as? SentenceTableViewCell else {
            return UITableViewCell()
        }
        let sentence = sentences[indexPath.row]
        cell.configure(with: sentence, showTranslation: showTranslation)
        return cell
    }
}

// MARK: - SentenceTableViewCell
class SentenceTableViewCell: UITableViewCell {
    private lazy var containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        if #available(iOS 8.2, *) {
            label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        } else {
            label.font = UIFont.boldSystemFont(ofSize: 11)
        }
        // Material Design onSurfaceVariant 颜色
        label.textColor = UIColor(red: 0.46, green: 0.46, blue: 0.51, alpha: 1.0)
        return label
    }()
    
    private lazy var languageLabel: UILabel = {
        let label = UILabel()
        if #available(iOS 8.2, *) {
            label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        } else {
            label.font = UIFont.boldSystemFont(ofSize: 10)
        }
        label.textColor = .white
        // Material Design secondaryContainer 颜色
        label.backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        return label
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        if #available(iOS 8.2, *) {
            label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        } else {
            label.font = UIFont.boldSystemFont(ofSize: 10)
        }
        label.textColor = .white
        // Material Design tertiaryContainer 颜色
        label.backgroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.text = "识别中"
        return label
    }()
    
    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        // Material Design onSurface 颜色
        label.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var translationsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 6
        return stackView
    }()
    
    private lazy var separatorView: UIView = {
        let view = UIView()
        // Material Design outlineVariant 颜色
        view.backgroundColor = UIColor(red: 0.78, green: 0.78, blue: 0.82, alpha: 1.0)
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(timeLabel)
        containerView.addSubview(languageLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(contentLabel)
        containerView.addSubview(separatorView)
        containerView.addSubview(translationsStackView)
        
        // 使用SnapKit设置约束
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }
        
        timeLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(12)
        }
        
        languageLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.size.equalTo(CGSize(width: 40, height: 20))
        }
        
        statusLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.trailing.equalTo(languageLabel.snp.leading).offset(-8)
            make.size.equalTo(CGSize(width: 50, height: 20))
        }
        
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(1)
        }
        
        translationsStackView.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
    
    func configure(with sentence: SttSentence, showTranslation: Bool) {
        // 设置时间标签
        if sentence.isFinal {
            timeLabel.text = "(\(sentence.startTs), \(sentence.endTs)]"
        } else {
            timeLabel.text = "(\(sentence.startTs), ...)"
        }
        
        // 设置语言标签
        languageLabel.text = sentence.lang.uppercased()
        
        // 设置状态标签
        statusLabel.isHidden = sentence.isFinal
        
        // 设置文本
        contentLabel.text = sentence.text
      
        contentLabel.font = UIFont.systemFont(ofSize: 15)
        
        // 设置容器背景色
        if sentence.isFinal {
            // Material Design surface 颜色
            containerView.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0)
            containerView.layer.shadowColor = UIColor.black.cgColor
            containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
            containerView.layer.shadowOpacity = 0.1
            containerView.layer.shadowRadius = 2
        } else {
            // Material Design surfaceVariant 颜色 (半透明)
            containerView.backgroundColor = UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 0.5)
            containerView.layer.shadowOpacity = 0
        }
        
        // 清空翻译视图
        translationsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 设置翻译内容
        let hasTranslations = showTranslation && !sentence.translations.isEmpty
        separatorView.isHidden = !hasTranslations
        translationsStackView.isHidden = !hasTranslations
        
        if hasTranslations {
            for (lang, translationData) in sentence.translations {
                let translationView = createTranslationView(lang: lang, text: translationData.text)
                translationsStackView.addArrangedSubview(translationView)
            }
        }
    }
    
    private func createTranslationView(lang: String, text: String) -> UIView {
        let containerView = UIView()
        // Material Design secondaryContainer 颜色 (浅色)
        containerView.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        containerView.layer.cornerRadius = 6
        
        let langLabel = UILabel()
        langLabel.text = lang.uppercased()
        if #available(iOS 8.2, *) {
            langLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        } else {
            langLabel.font = UIFont.boldSystemFont(ofSize: 10)
        }
        langLabel.textColor = .white
        // Material Design secondary 颜色
        langLabel.backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        langLabel.textAlignment = .center
        langLabel.layer.cornerRadius = 4
        langLabel.layer.masksToBounds = true
        
        let contentLabel = UILabel()
        contentLabel.text = text
        contentLabel.font = UIFont.systemFont(ofSize: 13)
        // Material Design onSurface 颜色
        contentLabel.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        contentLabel.numberOfLines = 0
        
        containerView.addSubview(langLabel)
        containerView.addSubview(contentLabel)
        
        // 使用SnapKit设置约束
        langLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(8)
            make.size.equalTo(CGSize(width: 40, height: 20))
        }
        
        contentLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalTo(langLabel.snp.trailing).offset(8)
            make.trailing.bottom.equalToSuperview().inset(8)
        }
        
        return containerView
    }
}

struct STTResponseModel: Codable {
    let agentId: String?
    let agentUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case agentUrl = "agent_url"
    }
}
