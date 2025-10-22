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
    let translations: [String: String] // lang -> text
    let uid: UInt
    
    init(id: Int = 0, startTs: Int, endTs: Int, text: String, lang: String, isFinal: Bool, translations: [String: String] = [:], uid: UInt) {
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


/**
 * STT Message Renderer
 * Handles message rendering based on time ranges
 */
class SttMessageRenderer {
    private var sentences: [SttSentence] = []
    var processingMode: SttProcessingMode = .async
    
    /**
     * Process incoming STT message
     * Returns updated list of sentences
     */
    func processMessage(_ message: AgoraSttMessage) -> [SttSentence] {
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
                // Update last Non-final to Final
                let newSentence = SttSentence(
                    id: lastSentence.startTs,
                    startTs: lastSentence.startTs,
                    endTs: endTs,
                    text: transcription.text,
                    lang: transcription.lang,
                    isFinal: true,
                    uid: message.sttUid
                )
                sentences[sentences.count - 1] = newSentence
            } else {
                // Create new Final sentence (no pending Non-final, or last is already Final)
                let startTs = lastSentence?.endTs ?? 0
                
                // Validate timestamp: endTs must be > startTs
                if endTs <= startTs {
                    return  // Discard out-of-order Final message
                }
                
                let newSentence = SttSentence(
                    id: startTs,
                    startTs: startTs,
                    endTs: endTs,
                    text: transcription.text,
                    lang: transcription.lang,
                    isFinal: true,
                    uid: message.sttUid
                )
                sentences.append(newSentence)
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
                }
                // else: ignore older out-of-order message
            } else {
                // Create new Non-final sentence
                let startTs = lastSentence?.endTs ?? 0
                
                // Validate timestamp: textTs must be > startTs
                if textTs <= startTs {
                    return  // Discard out-of-order message
                }
                
                let newSentence = SttSentence(
                    id: startTs,
                    startTs: startTs,
                    endTs: textTs,
                    text: transcription.text,
                    lang: transcription.lang,
                    isFinal: false,
                    uid: message.sttUid
                )
                sentences.append(newSentence)
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
            // Update translations for this sentence
//            AgoraSttTranslation
            
            var updatedTranslations = targetSentence.translations
            for translation in translations {
                if let translation = translation as? AgoraSttTranslation {
                    updatedTranslations[translation.sttTranslationLang] = translation.sttTranslationText
                }
            }
            
            let updatedSentence = SttSentence(
                id: targetSentence.id,
                startTs: targetSentence.startTs,
                endTs: targetSentence.endTs,
                text: targetSentence.text,
                lang: targetSentence.lang,
                isFinal: targetSentence.isFinal,
                translations: updatedTranslations,
                uid: targetSentence.uid
            )
            
            // Replace the sentence
            if let index = sentences.firstIndex(where: { $0.id == targetSentence.id && $0.startTs == targetSentence.startTs }) {
                sentences[index] = updatedSentence
            }
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
        var translationsMap: [String: String] = [:]
        for translation in translations {
            if let translation = translation as? AgoraSttTranslation {
                translationsMap[translation.sttTranslationLang] = translation.sttTranslationText
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
                // Both are Final: append translations (keep original text)
                var mergedTranslations = existingSentence.translations
                for (key, value) in translationsMap {
                    mergedTranslations[key] = value
                }
                
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
                let startTs = existingSentence.endTs
                
                // Validate timestamp
                if textTs <= startTs {
                    return  // Invalid timestamp
                }
                
                let newSentence = SttSentence(
                    id: startTs,
                    startTs: startTs,
                    endTs: textTs,
                    text: transcription.text,
                    lang: transcription.lang,
                    isFinal: false,
                    translations: translationsMap,
                    uid: message.sttUid
                )
                sentences.append(newSentence)
            }
            return
        }
        
        // No existing Final sentence hit, process normally
        if transcription.isFinal {
            // Final message: finalize the last Non-final sentence or create new
            let endTs = textTs
            let lastSentence = sentences.last
            
            if let lastSentence = lastSentence, !lastSentence.isFinal {
                // Update last Non-final to Final (append translations)
                var mergedTranslations = lastSentence.translations
                for (key, value) in translationsMap {
                    mergedTranslations[key] = value
                }
                
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
            } else {
                // Create new Final sentence (no pending Non-final, or last is already Final)
                let startTs = lastSentence?.endTs ?? 0
                
                // Validate timestamp: endTs must be > startTs
                if endTs <= startTs {
                    return  // Discard out-of-order Final message
                }
                
                let newSentence = SttSentence(
                    id: startTs,
                    startTs: startTs,
                    endTs: endTs,
                    text: transcription.text,
                    lang: transcription.lang,
                    isFinal: true,
                    translations: translationsMap,
                    uid: message.sttUid
                )
                sentences.append(newSentence)
            }
        } else {
            // Non-final message: update or create temporary sentence (with translations)
            let lastSentence = sentences.last
            
            if let lastSentence = lastSentence, !lastSentence.isFinal {
                // Update existing Non-final sentence
                // Only update if new timestamp >= old timestamp
                if textTs >= lastSentence.endTs {
                    // Append translations
                    var mergedTranslations = lastSentence.translations
                    for (key, value) in translationsMap {
                        mergedTranslations[key] = value
                    }
                    
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
                let startTs = lastSentence?.endTs ?? 0
                
                // Validate timestamp: textTs must be > startTs
                if textTs <= startTs {
                    return  // Discard out-of-order message
                }
                
                let newSentence = SttSentence(
                    id: startTs,
                    startTs: startTs,
                    endTs: textTs,
                    text: transcription.text,
                    lang: transcription.lang,
                    isFinal: false,
                    translations: translationsMap,
                    uid: message.sttUid
                )
                sentences.append(newSentence)
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
