package io.agora.api.example.examples.advanced.stt

import io.agora.rtc2.stt.SttMessage
import io.agora.rtc2.stt.SttMessageType

/**
 * STT Processing Mode
 */
enum class SttProcessingMode {
    ASYNC,  // Transcription and translation async mode (default)
    SYNC    // Transcription and translation sync mode (filters messages without translation)
}

/**
 * Translation data with final state
 * @property text The translated text content
 * @property ts Timestamp of the translation (from sttTextTs)
 * @property isFinal Whether this translation is finalized (from SttTranslation.isFinal)
 */
data class TranslationData(
    val text: String,
    val ts: Long,
    val isFinal: Boolean
)

/**
 * STT Sentence
 * Represents a transcribed sentence with optional translations
 * @property id Sentence unique ID from SDK (sttSentenceId)
 * @property textTs Timestamp of the text (from sttTextTs)
 * @property text The transcribed text content
 * @property lang Source language code (e.g., "zh-CN", "en-US")
 * @property isFinal Whether this sentence is finalized
 * @property translations Map of language code to translation data
 * @property uid User ID of the speaker
 */
data class SttSentence(
    val id: Long = 0,
    val textTs: Long,
    val text: String,
    val lang: String,
    val isFinal: Boolean,
    val translations: Map<String, TranslationData> = emptyMap(),
    val uid: Long
)

/**
 * STT Message Renderer
 * Handles message rendering based on time ranges
 * @property onDebug Optional callback for debug logging
 */
class SttMessageRenderer(val onDebug: ((message: String) -> Unit)?) {
    private val sentences = mutableListOf<SttSentence>()

    /**
     * Processing mode for STT messages (ASYNC or SYNC)
     */
    var processingMode: SttProcessingMode = SttProcessingMode.ASYNC
        set(value) {
            field = value
            onDebug?.invoke("SttProcessingMode: $value")
        }

    /**
     * Merge translations with out-of-order protection
     * If existing translation is Final, don't overwrite with non-final
     * If new translation is Final, always use it
     * If both have same final state, use the one with newer timestamp (ts)
     */
    private fun mergeTranslations(
        existing: Map<String, TranslationData>,
        new: Map<String, TranslationData>
    ): Map<String, TranslationData> {
        val merged = existing.toMutableMap()
        new.forEach { (lang, newData) ->
            val existingData = merged[lang]
            if (existingData == null) {
                // No existing translation, add new one
                merged[lang] = newData
            } else if (existingData.isFinal && !newData.isFinal) {
                // Rule 1: Existing is Final and new is not, keep existing (don't overwrite)
            } else if (!existingData.isFinal && !newData.isFinal) {
                // Rule 2: Both are Non-Final, update only if new ts >= existing ts
                if (newData.ts >= existingData.ts) {
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
    private fun insertSentenceInOrder(sentence: SttSentence) {
        // Find insertion index using binary search
        var left = 0
        var right = sentences.size
        
        while (left < right) {
            val mid = (left + right) / 2
            if (sentences[mid].id < sentence.id) {
                left = mid + 1
            } else {
                right = mid
            }
        }
        
        sentences.add(left, sentence)
    }

    /**
     * Process incoming STT message
     * Returns updated list of sentences
     */
    fun processMessage(message: SttMessage): List<SttSentence> {
        when (processingMode) {
            SttProcessingMode.ASYNC -> {
                // Async mode: process transcription and translation messages separately
                when (message.sttMessageType) {
                    SttMessageType.STT_MESSAGE_TYPE_TRANSCRIPTION -> {
                        processTranscription(message)
                    }

                    SttMessageType.STT_MESSAGE_TYPE_TRANSLATION -> {
                        processTranslation(message)
                    }

                    else -> {}
                }
            }

            SttProcessingMode.SYNC -> {
                // Sync mode: only process translation messages, which contain both transcription and translation
                if (message.sttMessageType == SttMessageType.STT_MESSAGE_TYPE_TRANSLATION) {
                    processTranslationSync(message)
                }
                // Ignore pure transcription messages
            }
        }

        return sentences.toList()
    }

    private fun processTranscription(message: SttMessage) {
        val transcription = message.sttTranscription ?: return
        val sentenceId = message.sttSentenceId
        val textTs = message.sttTextTs

        // Find existing sentence by sentenceId
        val existingIndex = sentences.indexOfFirst { it.id == sentenceId }

        if (existingIndex >= 0) {
            // Update existing sentence
            val existingSentence = sentences[existingIndex]
            
            // Rule 1: If existing is Final and new is not Final, ignore (don't overwrite Final with Non-Final)
            if (existingSentence.isFinal && !transcription.isFinal) {
                onDebug?.invoke("Ignore: Existing Final sentence cannot be overwritten by Non-Final [sentenceId=$sentenceId]")
                return
            }
            
            // Rule 2: If both are Non-Final, only update if new textTs >= existing textTs
            if (!existingSentence.isFinal && !transcription.isFinal) {
                if (textTs < existingSentence.textTs) {
                    onDebug?.invoke("Ignore: Non-Final with smaller textTs cannot overwrite larger " +
                            "[sentenceId=$sentenceId, existing=${existingSentence.textTs}, new=$textTs]")
                    return
                }
            }
            
            // Update sentence (passed all checks)
            val updatedSentence = existingSentence.copy(
                textTs = textTs,
                text = transcription.text ?: "",
                lang = transcription.lang ?: "",
                isFinal = transcription.isFinal
                // Keep existing translations, don't overwrite
            )
            sentences[existingIndex] = updatedSentence
            onDebug?.invoke("Transcript ${if (transcription.isFinal) "Final" else "Non-Final"}: Update [sentenceId=$sentenceId, textTs=$textTs] \"${transcription.text}\"")
        } else {
            // Create new sentence
            val newSentence = SttSentence(
                id = sentenceId,
                textTs = textTs,
                text = transcription.text ?: "",
                lang = transcription.lang ?: "",
                isFinal = transcription.isFinal,
                uid = message.sttUid
            )
            insertSentenceInOrder(newSentence)
            onDebug?.invoke("Transcript ${if (transcription.isFinal) "Final" else "Non-Final"}: Create [sentenceId=$sentenceId, textTs=$textTs] \"${transcription.text}\"")
        }
    }

    private fun processTranslation(message: SttMessage) {
        val translations = message.sttTranslations ?: return
        val sentenceId = message.sttSentenceId
        val textTs = message.sttTextTs

        // Find the sentence by sentenceId
        val targetIndex = sentences.indexOfFirst { it.id == sentenceId }

        if (targetIndex < 0) {
            onDebug?.invoke("Ignore: Translation no matching sentence (sentenceId=$sentenceId)")
            return
        }

        val targetSentence = sentences[targetIndex]

        // Build new translations map
        val newTranslations = mutableMapOf<String, TranslationData>()
        translations.forEach { translation ->
            newTranslations[translation.sttTranslationLang ?: ""] = TranslationData(
                text = translation.sttTranslationText ?: "",
                ts = textTs,
                isFinal = translation.isFinal
            )
        }

        // Merge with existing translations (with Final protection)
        val mergedTranslations = mergeTranslations(targetSentence.translations, newTranslations)

        val updatedSentence = targetSentence.copy(
            translations = mergedTranslations
        )

        // Replace the sentence
        sentences[targetIndex] = updatedSentence
        onDebug?.invoke("Translation: [sentenceId=$sentenceId, textTs=${updatedSentence.textTs}] \"${updatedSentence.translations}\"")
    }

    /**
     * Process translation message in SYNC mode
     * Translation message contains both transcription and translation
     */
    private fun processTranslationSync(message: SttMessage) {
        val transcription = message.sttTranscription ?: return
        val translations = message.sttTranslations ?: return
        val sentenceId = message.sttSentenceId
        val textTs = message.sttTextTs

        // Build translations map
        val translationsMap = mutableMapOf<String, TranslationData>()
        translations.forEach { translation ->
            translationsMap[translation.sttTranslationLang ?: ""] = TranslationData(
                text = translation.sttTranslationText ?: "",
                ts = textTs,
                isFinal = translation.isFinal
            )
        }

        // Find existing sentence by sentenceId
        val existingIndex = sentences.indexOfFirst { it.id == sentenceId }

        if (existingIndex >= 0) {
            // Update existing sentence
            val existingSentence = sentences[existingIndex]
            
            // Rule 1: If existing is Final and new is not Final, ignore (don't overwrite Final with Non-Final)
            if (existingSentence.isFinal && !transcription.isFinal) {
                onDebug?.invoke("Ignore: Existing Final sentence cannot be overwritten by Non-Final [sentenceId=$sentenceId]")
                return
            }
            
            // Rule 2: If both are Non-Final, only update if new textTs >= existing textTs
            if (!existingSentence.isFinal && !transcription.isFinal) {
                if (textTs < existingSentence.textTs) {
                    onDebug?.invoke("Ignore: Non-Final with smaller textTs cannot overwrite larger " +
                            "[sentenceId=$sentenceId, existing=${existingSentence.textTs}, new=$textTs]")
                    return
                }
            }
            
            // Merge translations (with Final protection)
            val mergedTranslations = mergeTranslations(existingSentence.translations, translationsMap)

            // Update sentence (passed all checks)
            val updatedSentence = existingSentence.copy(
                textTs = textTs,
                text = transcription.text ?: "",
                lang = transcription.lang ?: "",
                isFinal = transcription.isFinal,
                translations = mergedTranslations
            )
            sentences[existingIndex] = updatedSentence
            onDebug?.invoke("SYNC ${if (transcription.isFinal) "Final" else "Non-Final"}: Update [sentenceId=$sentenceId, textTs=$textTs] \"${transcription.text}\"")
        } else {
            // Create new sentence
            val newSentence = SttSentence(
                id = sentenceId,
                textTs = textTs,
                text = transcription.text ?: "",
                lang = transcription.lang ?: "",
                isFinal = transcription.isFinal,
                translations = translationsMap,
                uid = message.sttUid
            )
            insertSentenceInOrder(newSentence)
            onDebug?.invoke("SYNC ${if (transcription.isFinal) "Final" else "Non-Final"}: Create [sentenceId=$sentenceId, textTs=$textTs] \"${transcription.text}\"")
        }
    }

    /**
     * Clear all stored sentences
     */
    fun clear() {
        sentences.clear()
    }

    /**
     * Get a copy of all stored sentences
     * @return Immutable list of STT sentences
     */
    fun getSentences(): List<SttSentence> = sentences.toList()
}
