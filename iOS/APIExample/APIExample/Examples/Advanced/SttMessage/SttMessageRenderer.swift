//
//  SttMessageRenderer.swift
//  APIExample
//
//  Created by qinhui on 2025/10/22.
//  Copyright © 2025 Agora Corp. All rights reserved.
//

import Foundation
import AgoraRtcKit

/**
 * STT Processing Mode
 */
enum SttProcessingMode {
    case async  // 转写翻译异步模式 (默认)
    case sync   // 转写翻译同步模式 (过滤无翻译的消息)
}

/**
 * Translation data with timestamp
 */
struct TranslationData {
    let text: String
    let ts: Int
    
    init(text: String, ts: Int) {
        self.text = text
        self.ts = ts
    }
}

/**
 * STT Sentence
 * Represents a transcribed sentence with optional translations
 */
struct SttSentence {
    let id: Int         // Reserved for future use (sentence unique ID from SDK)
    let startTs: Int    // Start timestamp
    let endTs: Int      // End timestamp (Final: fixed, Non-final: current textTs)
    let text: String
    let lang: String
    let isFinal: Bool
    let translations: [String: TranslationData] // lang -> TranslationData
    let uid: UInt
    
    init(id: Int = 0, startTs: Int, endTs: Int, text: String, lang: String, isFinal: Bool, translations: [String: TranslationData] = [:], uid: UInt) {
        self.id = id
        self.startTs = startTs
        self.endTs = endTs
        self.text = text
        self.lang = lang
        self.isFinal = isFinal
        self.translations = translations
        self.uid = uid
    }
}

protocol SttMessageRendererDelegate: AnyObject {
    func onDebugLog(_ log: String)
}

/**
 * STT Message Renderer
 * Handles message rendering based on time ranges
 */
class SttMessageRenderer {
    private var sentences: [SttSentence] = []
    weak var delegate: SttMessageRendererDelegate?
    var processingMode: SttProcessingMode = .async
    /**
     * Merge translations with timestamp-based protection
     * Only update if new timestamp is newer
     */
    private func mergeTranslations(
        existing: [String: TranslationData],
        new: [String: TranslationData]
    ) -> [String: TranslationData] {
        var merged = existing
        for (lang, newData) in new {
            let existingData = merged[lang]
            if existingData == nil || newData.ts > existingData!.ts {
                // No existing translation or new timestamp is newer: update
                merged[lang] = newData
            }
            // else: existing timestamp is newer or equal, don't overwrite
        }
        return merged
    }
    
    /**
     * Process incoming STT message
     * Returns updated list of sentences
     */
    func processMessage(_ message: AgoraSttMessage) -> [SttSentence] {
        self.delegate?.onDebugLog(">>>>>> [processMessage]: message: \(message), processingMode: \(processingMode)")
        
        switch processingMode {
        case .async:
            // 异步模式: 分别处理转写和翻译消息
            switch message.sttMessageType {
            case .transcription:
                processTranscription(message)
            case .translation:
                processTranslation(message)
            default:
                break
            }
        case .sync:
            // 同步模式: 只处理翻译消息,翻译消息中包含转写+翻译
            if message.sttMessageType == .translation {
                processTranslationSync(message)
            }
            // 忽略纯转写消息
        }
        return sentences
    }
    
    private func processTranscription(_ message: AgoraSttMessage) {
        let transcription = message.sttTranscription
        let textTs = message.sttTextTs
        
        if transcription.isFinal {
            // Final message: finalize the last Non-final sentence or create new
            let endTs = textTs
            let lastSentence = sentences.last
            
            if let lastSentence = lastSentence, !lastSentence.isFinal {
                let lastStartTs = lastSentence.startTs
                if endTs > lastStartTs {
                    // Update last Non-final to Final (keep existing translations)
                    let newSentence = SttSentence(
                        id: lastSentence.id,
                        startTs: lastSentence.startTs,
                        endTs: endTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: true,
                        translations: lastSentence.translations, // 保留现有翻译
                        uid: message.sttUid
                    )
                    sentences[sentences.count - 1] = newSentence
                } else {
                    self.delegate?.onDebugLog(">>>>>[processTranscription] 收到Final乱序消息，丢弃! transcription\(transcription), lastSentence: \(lastSentence)")
                }
                // else: ignore older out-of-order message
            } else {
                // Create new Final sentence (no pending Non-final, or last is already Final)
                let lastEndTs = lastSentence?.endTs ?? 0
                
                // Validate timestamp: endTs must be > lastEndTs
                if endTs > lastEndTs {
                    let newSentence = SttSentence(
                        id: lastEndTs,
                        startTs: lastEndTs,
                        endTs: endTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: true,
                        uid: message.sttUid
                    )
                    sentences.append(newSentence)
                } else {
                    self.delegate?.onDebugLog(">>>>>[processTranscription] 收到Final乱序消息，丢弃! transcription\(transcription), lastSentence: \(lastSentence)")
                    // ignore older out-of-order message
                }
            }
        } else {
            // Non-final message: update or create temporary sentence
            let lastSentence = sentences.last
            
            if let lastSentence = lastSentence, !lastSentence.isFinal {
                // Update existing Non-final sentence
                // Only update if new timestamp >= old timestamp
                if textTs >= lastSentence.endTs {
                    let newSentence = SttSentence(
                        id: lastSentence.id,
                        startTs: lastSentence.startTs,
                        endTs: textTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: false,
                        translations: lastSentence.translations,
                        uid: message.sttUid
                    )
                    sentences[sentences.count - 1] = newSentence
                } else {
                    self.delegate?.onDebugLog(">>>>>[processTranscription] 收到非Final乱序消息，丢弃! transcription\(transcription), lastSentence: \(lastSentence)")
                }
                // else: ignore older out-of-order message
            } else {
                // Create new Non-final sentence
                let lastEndTs = lastSentence?.endTs ?? 0
                
                // Validate timestamp: textTs must be > lastEndTs
                if textTs > lastEndTs {
                    let newSentence = SttSentence(
                        id: lastEndTs,
                        startTs: lastEndTs,
                        endTs: textTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: false,
                        uid: message.sttUid
                    )
                    sentences.append(newSentence)
                } else {
                    self.delegate?.onDebugLog(">>>>>[processTranscription] 收到非Final乱序消息，丢弃! transcription\(transcription), lastSentence: \(lastSentence)")
                    // ignore older out-of-order message
                }
            }
        }
    }
    
    private func processTranslation(_ message: AgoraSttMessage) {
        let translations = message.sttTranslations
        
        // Find the sentence by time range
        let targetTs = message.sttTextTs
        let targetSentence = sentences.last { sentence in
            sentence.startTs < targetTs && targetTs <= sentence.endTs
        }
        
        if let targetSentence = targetSentence {
            // Build new translations map
            var newTranslations: [String: TranslationData] = [:]
            for translation in translations {
                if let translation = translation as? AgoraSttTranslation {
                    newTranslations[translation.sttTranslationLang] = TranslationData(
                        text: translation.sttTranslationText,
                        ts: targetTs
                    )
                }
            }
            
            // Merge with existing translations (with timestamp protection)
            let mergedTranslations = mergeTranslations(existing: targetSentence.translations, new: newTranslations)
            
            let updatedSentence = SttSentence(
                id: targetSentence.id,
                startTs: targetSentence.startTs,
                endTs: targetSentence.endTs,
                text: targetSentence.text,
                lang: targetSentence.lang,
                isFinal: targetSentence.isFinal,
                translations: mergedTranslations,
                uid: targetSentence.uid
            )
            
            // Replace the sentence
            if let index = sentences.firstIndex(where: { $0.id == targetSentence.id && $0.startTs == targetSentence.startTs }) {
                sentences[index] = updatedSentence
            }
        } else {
            self.delegate?.onDebugLog(">>>>>[processTranslation] 翻译未找到对应转写，丢弃! transcription\(translations)")
        }
    }
    
    /**
     * Process translation message in SYNC mode
     * Translation message contains both transcription and translation
     */
    private func processTranslationSync(_ message: AgoraSttMessage) {
        let transcription = message.sttTranscription
        let translations = message.sttTranslations
        let textTs = message.sttTextTs
        
        // Build translations map
        var translationsMap: [String: TranslationData] = [:]
        for translation in translations {
            if let translation = translation as? AgoraSttTranslation {
                translationsMap[translation.sttTranslationLang] = TranslationData(
                    text: translation.sttTranslationText,
                    ts: textTs
                )
            }
        }
        
        // Check if textTs hits an existing sentence's time range
        let existingSentence = sentences.last { sentence in
            sentence.startTs < textTs && textTs <= sentence.endTs
        }
        
        if let existingSentence = existingSentence, existingSentence.isFinal {
            // Hit an existing Final sentence
            // Check if this translation message is also Final
            if transcription.isFinal {
                // Both are Final: merge translations with timestamp protection
                let mergedTranslations = mergeTranslations(existing: existingSentence.translations, new: translationsMap)
                
                let updatedSentence = SttSentence(
                    id: existingSentence.id,
                    startTs: existingSentence.startTs,
                    endTs: existingSentence.endTs,
                    text: existingSentence.text,
                    lang: existingSentence.lang,
                    isFinal: existingSentence.isFinal,
                    translations: mergedTranslations,
                    uid: existingSentence.uid
                )
                
                if let index = sentences.firstIndex(where: { $0.id == existingSentence.id && $0.startTs == existingSentence.startTs }) {
                    sentences[index] = updatedSentence
                }
            } else {
                // Translation is Non-final but sentence is Final
                // This is a new sentence, create it after the Final one
                let existingEndTs = existingSentence.endTs
                
                // Validate timestamp
                if textTs > existingEndTs {
                    let newSentence = SttSentence(
                        id: existingEndTs,
                        startTs: existingEndTs,
                        endTs: textTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: false,
                        translations: translationsMap,
                        uid: message.sttUid
                    )
                    sentences.append(newSentence)
                }
                // else: ignore older out-of-order message
            }
            return
        }
        
        // No existing Final sentence hit, process normally
        if transcription.isFinal {
            // Final message: finalize the last Non-final sentence or create new
            let endTs = textTs
            let lastSentence = sentences.last
            
            if let lastSentence = lastSentence, !lastSentence.isFinal {
                let lastStartTs = lastSentence.startTs
                if endTs > lastStartTs {
                    // Update last Non-final to Final (merge translations with timestamp protection)
                    let mergedTranslations = mergeTranslations(existing: lastSentence.translations, new: translationsMap)
                    
                    let newSentence = SttSentence(
                        id: lastSentence.startTs,
                        startTs: lastSentence.startTs,
                        endTs: endTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: true,
                        translations: mergedTranslations,
                        uid: message.sttUid
                    )
                    sentences[sentences.count - 1] = newSentence
                }
                // else: ignore older out-of-order message
            } else {
                // Create new Final sentence (no pending Non-final, or last is already Final)
                let lastEndTs = lastSentence?.endTs ?? 0
                
                // Validate timestamp: endTs must be > lastEndTs
                if endTs > lastEndTs {
                    let newSentence = SttSentence(
                        id: lastEndTs,
                        startTs: lastEndTs,
                        endTs: endTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: true,
                        translations: translationsMap,
                        uid: message.sttUid
                    )
                    sentences.append(newSentence)
                }
                // else: ignore older out-of-order message
            }
        } else {
            // Non-final message: update or create temporary sentence (with translations)
            let lastSentence = sentences.last
            
            if let lastSentence = lastSentence, !lastSentence.isFinal {
                // Update existing Non-final sentence
                // Only update if new timestamp >= old timestamp
                if textTs >= lastSentence.endTs {
                    // Merge translations with timestamp protection
                    let mergedTranslations = mergeTranslations(existing: lastSentence.translations, new: translationsMap)
                    
                    let newSentence = SttSentence(
                        id: lastSentence.id,
                        startTs: lastSentence.startTs,
                        endTs: textTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: false,
                        translations: mergedTranslations,
                        uid: message.sttUid
                    )
                    sentences[sentences.count - 1] = newSentence
                }
                // else: ignore older out-of-order message
            } else {
                // Create new Non-final sentence
                let lastEndTs = lastSentence?.endTs ?? 0
                
                // Validate timestamp: textTs must be > lastEndTs
                if textTs > lastEndTs {
                    let newSentence = SttSentence(
                        id: lastEndTs,
                        startTs: lastEndTs,
                        endTs: textTs,
                        text: transcription.text,
                        lang: transcription.lang,
                        isFinal: false,
                        translations: translationsMap,
                        uid: message.sttUid
                    )
                    sentences.append(newSentence)
                }
                // else: ignore older out-of-order message
            }
        }
    }
    
    func clear() {
        sentences.removeAll()
    }
    
    func getSentences() -> [SttSentence] {
        return sentences
    }
}

extension SttMessageRendererDelegate {
    func onDebugLog(_ log: String) {}
}


// MARK: - AgoraSttMessage Extensions for Debug Printing
extension AgoraSttMessage {
    public override var description: String {
        return "AgoraSttMessage { uid: \(sttUid), sttStartTime:\(sttStartTime), sttMessageType: \(sttMessageType), sttTranscription: \(sttTranscription), sttDurationMs: \(sttDurationMs), sttTranslations: \(sttTranslations), sttTextTs: \(sttTextTs) }"
    }
}

// MARK: - AgoraSttTranscription Extension
extension AgoraSttTranscription {
    public override var description: String {
        return "AgoraSttTranscription { text: \"\(text)\", lang: \(lang), isFinal: \(isFinal) }"
    }
}

// MARK: - AgoraSttTranslation Extension
extension AgoraSttTranslation {
    public override var description: String {
        return "AgoraSttTranslation { text: \"\(sttTranslationText)\", lang: \(sttTranslationLang), isFinal: \(isFinal) }"
    }
}

