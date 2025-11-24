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
    case async  // Transcription and translation async mode (default)
    case sync   // Transcription and translation sync mode (filters messages without translation)
}

/**
 * Translation data with final state
 * @property text The translated text content
 * @property ts Timestamp of the translation (from sttTextTs)
 * @property isFinal Whether this translation is finalized (from SttTranslation.isFinal)
 */
struct TranslationData {
    let text: String
    let ts: Int
    let isFinal: Bool
    
    init(text: String, ts: Int, isFinal: Bool) {
        self.text = text
        self.ts = ts
        self.isFinal = isFinal
    }
}

/**
 * STT Sentence
 * Represents a transcribed sentence with optional translations
 * @property id Sentence unique ID from SDK (sttSentenceId, fallback to textTs if not available)
 * @property textTs Timestamp of the text (from sttTextTs)
 * @property text The transcribed text content
 * @property lang Source language code (e.g., "zh-CN", "en-US")
 * @property isFinal Whether this sentence is finalized
 * @property translations Map of language code to translation data
 * @property uid User ID of the speaker
 */
struct SttSentence {
    let id: Int
    let textTs: Int
    let text: String
    let lang: String
    let isFinal: Bool
    let translations: [String: TranslationData]
    let uid: UInt
    
    init(id: Int, textTs: Int, text: String, lang: String, isFinal: Bool, translations: [String: TranslationData] = [:], uid: UInt) {
        self.id = id
        self.textTs = textTs
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
 * Handles message rendering based on sentence ID
 */
class SttMessageRenderer {
    private var sentences: [SttSentence] = []
    weak var delegate: SttMessageRendererDelegate?
    
    var processingMode: SttProcessingMode = .async {
        didSet {
            delegate?.onDebugLog("SttProcessingMode: \(processingMode)")
        }
    }
    
    /**
     * Merge translations with out-of-order protection
     * If existing translation is Final, don't overwrite with non-final
     * If new translation is Final, always use it
     * If both have same final state, use the one with newer timestamp (ts)
     */
    private func mergeTranslations(
        existing: [String: TranslationData],
        new: [String: TranslationData]
    ) -> [String: TranslationData] {
        var merged = existing
        for (lang, newData) in new {
            let existingData = merged[lang]
            if existingData == nil {
                // No existing translation, add new one
                merged[lang] = newData
            } else if existingData!.isFinal && !newData.isFinal {
                // Rule 1: Existing is Final and new is not, keep existing (don't overwrite)
                // Do nothing
            } else if !existingData!.isFinal && !newData.isFinal {
                // Rule 2: Both are Non-Final, update only if new ts >= existing ts
                if newData.ts >= existingData!.ts {
                    merged[lang] = newData
                }
            } else {
                // Remaining cases:
                // 1. Existing Non-Final, New Final -> Update
                // 2. Existing Final, New Final -> Update (allow correction)
                merged[lang] = newData
            }
        }
        return merged
    }
    
    /**
     * Insert sentence in order by sentenceId (timestamp, always increasing)
     * @param sentence The sentence to insert
     */
    private func insertSentenceInOrder(_ sentence: SttSentence) {
        // Find insertion index using binary search
        var left = 0
        var right = sentences.count
        
        while left < right {
            let mid = (left + right) / 2
            if sentences[mid].id < sentence.id {
                left = mid + 1
            } else {
                right = mid
            }
        }
        
        sentences.insert(sentence, at: left)
    }
    
    /**
     * Get sentence ID from message
     * Uses sttSentenceId from SDK
     */
    private func getSentenceId(from message: AgoraSttMessage) -> Int {
        return Int(message.sttSentenceId)
    }
    
    /**
     * Process incoming STT message
     * Returns updated list of sentences
     */
    func processMessage(_ message: AgoraSttMessage) -> [SttSentence] {
        delegate?.onDebugLog(">>>>>> [processMessage]: message: \(message), processingMode: \(processingMode)")
        
        switch processingMode {
        case .async:
            // Async mode: process transcription and translation messages separately
            switch message.sttMessageType {
            case .transcription:
                processTranscription(message)
            case .translation:
                processTranslation(message)
            default:
                break
            }
        case .sync:
            // Sync mode: only process translation messages, which contain both transcription and translation
            if message.sttMessageType == .translation {
                processTranslationSync(message)
            }
            // Ignore pure transcription messages
        }
        
        return sentences
    }
    
    private func processTranscription(_ message: AgoraSttMessage) {
        let transcription = message.sttTranscription
        let sentenceId = getSentenceId(from: message)
        let textTs = Int(message.sttTextTs)
        
        // Find existing sentence by sentenceId
        let existingIndex = sentences.firstIndex { $0.id == sentenceId }
        
        if let index = existingIndex {
            // Update existing sentence
            let existingSentence = sentences[index]
            
            // Rule 1: If existing is Final and new is not Final, ignore (don't overwrite Final with Non-Final)
            if existingSentence.isFinal && !transcription.isFinal {
                delegate?.onDebugLog("Ignore: Existing Final sentence cannot be overwritten by Non-Final [sentenceId=\(sentenceId)]")
                return
            }
            
            // Rule 2: If both are Non-Final, only update if new textTs >= existing textTs
            if !existingSentence.isFinal && !transcription.isFinal {
                if textTs < existingSentence.textTs {
                    delegate?.onDebugLog("Ignore: Non-Final with smaller textTs cannot overwrite larger [sentenceId=\(sentenceId), existing=\(existingSentence.textTs), new=\(textTs)]")
                    return
                }
            }
            
            // Update sentence (passed all checks)
            let updatedSentence = SttSentence(
                id: existingSentence.id,
                textTs: textTs,
                text: transcription.text,
                lang: transcription.lang,
                isFinal: transcription.isFinal,
                translations: existingSentence.translations, // Keep existing translations, don't overwrite
                uid: message.sttUid
            )
            sentences[index] = updatedSentence
            delegate?.onDebugLog("Transcript \(transcription.isFinal ? "Final" : "Non-Final"): Update [sentenceId=\(sentenceId), textTs=\(textTs)] \"\(transcription.text)\"")
        } else {
            // Create new sentence
            let newSentence = SttSentence(
                id: sentenceId,
                textTs: textTs,
                text: transcription.text,
                lang: transcription.lang,
                isFinal: transcription.isFinal,
                uid: message.sttUid
            )
            insertSentenceInOrder(newSentence)
            delegate?.onDebugLog("Transcript \(transcription.isFinal ? "Final" : "Non-Final"): Create [sentenceId=\(sentenceId), textTs=\(textTs)] \"\(transcription.text)\"")
        }
    }
    
    private func processTranslation(_ message: AgoraSttMessage) {
        let translations = message.sttTranslations
        let sentenceId = getSentenceId(from: message)
        let textTs = Int(message.sttTextTs)
        
        // Find the sentence by sentenceId
        guard let targetIndex = sentences.firstIndex(where: { $0.id == sentenceId }) else {
            delegate?.onDebugLog("Ignore: Translation no matching sentence (sentenceId=\(sentenceId))")
            return
        }
        
        let targetSentence = sentences[targetIndex]
        
        // Build new translations map
        var newTranslations: [String: TranslationData] = [:]
        for translation in translations {
            if let translation = translation as? AgoraSttTranslation {
                newTranslations[translation.sttTranslationLang] = TranslationData(
                    text: translation.sttTranslationText,
                    ts: textTs,
                    isFinal: translation.isFinal
                )
            }
        }
        
        // Merge with existing translations (with Final protection)
        let mergedTranslations = mergeTranslations(existing: targetSentence.translations, new: newTranslations)
        
        let updatedSentence = SttSentence(
            id: targetSentence.id,
            textTs: targetSentence.textTs,
            text: targetSentence.text,
            lang: targetSentence.lang,
            isFinal: targetSentence.isFinal,
            translations: mergedTranslations,
            uid: targetSentence.uid
        )
        
        // Replace the sentence
        sentences[targetIndex] = updatedSentence
        delegate?.onDebugLog("Translation: [sentenceId=\(sentenceId), textTs=\(updatedSentence.textTs)] \"\(updatedSentence.translations)\"")
    }
    
    /**
     * Process translation message in SYNC mode
     * Translation message contains both transcription and translation
     */
    private func processTranslationSync(_ message: AgoraSttMessage) {
        let transcription = message.sttTranscription
        let translations = message.sttTranslations
        let sentenceId = getSentenceId(from: message)
        let textTs = Int(message.sttTextTs)
        
        // Build translations map
        var translationsMap: [String: TranslationData] = [:]
        for translation in translations {
            if let translation = translation as? AgoraSttTranslation {
                translationsMap[translation.sttTranslationLang] = TranslationData(
                    text: translation.sttTranslationText,
                    ts: textTs,
                    isFinal: translation.isFinal
                )
            }
        }
        
        // Find existing sentence by sentenceId
        let existingIndex = sentences.firstIndex { $0.id == sentenceId }
        
        if let index = existingIndex {
            // Update existing sentence
            let existingSentence = sentences[index]
            
            // Rule 1: If existing is Final and new is not Final, ignore (don't overwrite Final with Non-Final)
            if existingSentence.isFinal && !transcription.isFinal {
                delegate?.onDebugLog("Ignore: Existing Final sentence cannot be overwritten by Non-Final [sentenceId=\(sentenceId)]")
                return
            }
            
            // Rule 2: If both are Non-Final, only update if new textTs >= existing textTs
            if !existingSentence.isFinal && !transcription.isFinal {
                if textTs < existingSentence.textTs {
                    delegate?.onDebugLog("Ignore: Non-Final with smaller textTs cannot overwrite larger [sentenceId=\(sentenceId), existing=\(existingSentence.textTs), new=\(textTs)]")
                    return
                }
            }
            
            // Merge translations (with Final protection)
            let mergedTranslations = mergeTranslations(existing: existingSentence.translations, new: translationsMap)
            
            // Update sentence (passed all checks)
            let updatedSentence = SttSentence(
                id: existingSentence.id,
                textTs: textTs,
                text: transcription.text,
                lang: transcription.lang,
                isFinal: transcription.isFinal,
                translations: mergedTranslations,
                uid: message.sttUid
            )
            sentences[index] = updatedSentence
            delegate?.onDebugLog("SYNC \(transcription.isFinal ? "Final" : "Non-Final"): Update [sentenceId=\(sentenceId), textTs=\(textTs)] \"\(transcription.text)\"")
        } else {
            // Create new sentence
            let newSentence = SttSentence(
                id: sentenceId,
                textTs: textTs,
                text: transcription.text,
                lang: transcription.lang,
                isFinal: transcription.isFinal,
                translations: translationsMap,
                uid: message.sttUid
            )
            insertSentenceInOrder(newSentence)
            delegate?.onDebugLog("SYNC \(transcription.isFinal ? "Final" : "Non-Final"): Create [sentenceId=\(sentenceId), textTs=\(textTs)] \"\(transcription.text)\"")
        }
    }
    
    /**
     * Clear all stored sentences
     */
    func clear() {
        sentences.removeAll()
    }
    
    /**
     * Get a copy of all stored sentences
     * @return Immutable list of STT sentences
     */
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
        return "AgoraSttMessage { uid: \(sttUid), sttStartTime:\(sttStartTime), sttMessageType: \(sttMessageType), sttTranscription: \(sttTranscription), sttDurationMs: \(sttDurationMs), sttTranslations: \(sttTranslations), sttTextTs: \(sttTextTs), sttSentenceId: \(sttSentenceId) }"
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
