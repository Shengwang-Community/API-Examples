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
 * @property isFinal Whether this translation is finalized
 */
data class TranslationData(
    val text: String,
    val isFinal: Boolean
)

/**
 * STT Sentence
 * Represents a transcribed sentence with optional translations
 * @property id Reserved for future use (sentence unique ID from SDK)
 * @property startTs Start timestamp in milliseconds
 * @property endTs End timestamp (Final: fixed, Non-final: current textTs)
 * @property text The transcribed text content
 * @property lang Source language code (e.g., "zh-CN", "en-US")
 * @property isFinal Whether this sentence is finalized
 * @property translations Map of language code to translation data
 * @property uid User ID of the speaker
 */
data class SttSentence(
    val id: Long = 0,
    val startTs: Long,
    val endTs: Long,
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
     * If existing translation is Final, don't overwrite
     */
    private fun mergeTranslations(
        existing: Map<String, TranslationData>,
        new: Map<String, TranslationData>
    ): Map<String, TranslationData> {
        val merged = existing.toMutableMap()
        new.forEach { (lang, newData) ->
            val existingData = merged[lang]
            if (existingData == null || !existingData.isFinal) {
                // No existing translation or existing is Non-final: update
                merged[lang] = newData
            }
            // else: existing is Final, don't overwrite
        }
        return merged
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
        val textTs = message.sttTextTs

        if (transcription.isFinal) {
            // Final message: finalize the last Non-final sentence or create new
            val endTs = textTs
            val lastSentence = sentences.lastOrNull()

            if (lastSentence != null && !lastSentence.isFinal) {
                // Update last Non-final to Final (keep existing translations)
                val newSentence = lastSentence.copy(
                    endTs = endTs,
                    text = transcription.text ?: "",
                    lang = transcription.lang ?: "",
                    isFinal = true
                    // Keep existing translations, don't overwrite
                )
                sentences[sentences.lastIndex] = newSentence
                onDebug?.invoke("Transcript Final: Update [${lastSentence.startTs}-$endTs] \"${transcription.text}\"")
            } else {
                // Create new Final sentence (no pending Non-final, or last is already Final)
                val startTs = lastSentence?.endTs ?: 0

                // Validate timestamp: endTs must be > startTs
                if (endTs <= startTs) {
                    onDebug?.invoke("Discard: out-of-order Final (endTs=$endTs <= startTs=$startTs)")
                    return  // Discard out-of-order Final message
                }

                val newSentence = SttSentence(
                    id = startTs,
                    startTs = startTs,
                    endTs = endTs,
                    text = transcription.text ?: "",
                    lang = transcription.lang ?: "",
                    isFinal = true,
                    uid = message.sttUid
                )
                sentences.add(newSentence)
                onDebug?.invoke("Transcript Final: Create [$startTs-$endTs] \"${transcription.text}\"")
            }
        } else {
            // Non-final message: update or create temporary sentence
            val lastSentence = sentences.lastOrNull()

            if (lastSentence != null && !lastSentence.isFinal) {
                // Update existing Non-final sentence
                // Only update if new timestamp >= old timestamp
                if (textTs >= lastSentence.endTs) {
                    val newSentence = lastSentence.copy(
                        endTs = textTs,
                        text = transcription.text ?: "",
                        lang = transcription.lang ?: ""
                    )
                    sentences[sentences.lastIndex] = newSentence
                    onDebug?.invoke("Transcript Non-Final: Update [${lastSentence.startTs}-$textTs] \"${transcription.text}\"")
                } else {
                    onDebug?.invoke("Ignore: out-of-order Non-final (textTs=$textTs < lastEndTs=${lastSentence.endTs})")
                }
                // else: ignore older out-of-order message
            } else {
                // Create new Non-final sentence
                val startTs = lastSentence?.endTs ?: 0

                // Validate timestamp: textTs must be > startTs
                if (textTs <= startTs) {
                    onDebug?.invoke("Discard: out-of-order Non-final (textTs=$textTs <= startTs=$startTs)")
                    return  // Discard out-of-order message
                }

                val newSentence = SttSentence(
                    id = startTs,
                    startTs = startTs,
                    endTs = textTs,
                    text = transcription.text ?: "",
                    lang = transcription.lang ?: "",
                    isFinal = false,
                    uid = message.sttUid
                )
                sentences.add(newSentence)
                onDebug?.invoke("Transcript Non-Final: Create [$startTs-$textTs] \"${transcription.text}\"")
            }
        }
    }

    private fun processTranslation(message: SttMessage) {
        val translations = message.sttTranslations ?: return

        // Find the sentence by time range
        val targetTs = message.sttTextTs
        val targetSentence = sentences.findLast {
            it.startTs < targetTs && targetTs <= it.endTs
        }

        if (targetSentence == null) {
            onDebug?.invoke("Ignore: Translation no matching sentence (textTs=$targetTs)")
            return
        }

        // Build new translations map
        val newTranslations = mutableMapOf<String, TranslationData>()
        translations.forEach { translation ->
            newTranslations[translation.sttTranslationLang ?: ""] = TranslationData(
                text = translation.sttTranslationText ?: "",
                isFinal = translation.isFinal
            )
        }

        // Merge with existing translations (with Final protection)
        val mergedTranslations = mergeTranslations(targetSentence.translations, newTranslations)

        val updatedSentence = targetSentence.copy(
            translations = mergedTranslations
        )

        // Replace the sentence
        val index = sentences.indexOf(targetSentence)
        if (index >= 0) {
            sentences[index] = updatedSentence
            onDebug?.invoke("Translation: [${targetSentence.startTs}-${targetSentence.endTs}] langs=${translations.size}")
        } else {
            onDebug?.invoke("Ignore: Translation sentence not found in list")
        }
    }

    /**
     * Process translation message in SYNC mode
     * Translation message contains both transcription and translation
     */
    private fun processTranslationSync(message: SttMessage) {
        val transcription = message.sttTranscription ?: return
        val translations = message.sttTranslations ?: return
        val textTs = message.sttTextTs

        // Build translations map
        val translationsMap = mutableMapOf<String, TranslationData>()
        translations.forEach { translation ->
            translationsMap[translation.sttTranslationLang ?: ""] = TranslationData(
                text = translation.sttTranslationText ?: "",
                isFinal = translation.isFinal
            )
        }

        // Check if textTs hits an existing sentence's time range
        val existingSentence = sentences.findLast {
            it.startTs < textTs && textTs <= it.endTs
        }

        if (existingSentence != null && existingSentence.isFinal) {
            // Hit an existing Final sentence
            // Check if this translation message is also Final
            if (transcription.isFinal) {
                // Both are Final: merge translations with Final protection
                val mergedTranslations = mergeTranslations(existingSentence.translations, translationsMap)

                val updatedSentence = existingSentence.copy(
                    translations = mergedTranslations
                )
                val index = sentences.indexOf(existingSentence)
                if (index >= 0) {
                    sentences[index] = updatedSentence
                    onDebug?.invoke("SYNC Final: Merge translation [${existingSentence.startTs}-${existingSentence.endTs}]")
                } else {
                    onDebug?.invoke("Ignore: Translation sentence not found in list")
                }
            } else {
                // Translation is Non-final but sentence is Final
                // This is a new sentence, create it after the Final one
                val startTs = existingSentence.endTs

                // Validate timestamp
                if (textTs <= startTs) {
                    onDebug?.invoke("Discard: SYNC invalid timestamp (textTs=$textTs <= startTs=$startTs)")
                    return  // Invalid timestamp
                }

                val newSentence = SttSentence(
                    id = startTs,
                    startTs = startTs,
                    endTs = textTs,
                    text = transcription.text ?: "",
                    lang = transcription.lang ?: "",
                    isFinal = false,
                    translations = translationsMap,
                    uid = message.sttUid
                )
                sentences.add(newSentence)
                onDebug?.invoke("SYNC Non-Final: Create [$startTs-$textTs] \"${transcription.text}\"")
            }
            return
        }

        // No existing Final sentence hit, process normally
        if (transcription.isFinal) {
            // Final message: finalize the last Non-final sentence or create new
            val endTs = textTs
            val lastSentence = sentences.lastOrNull()

            if (lastSentence != null && !lastSentence.isFinal) {
                // Update last Non-final to Final (merge translations with Final protection)
                val mergedTranslations = mergeTranslations(lastSentence.translations, translationsMap)

                val newSentence = SttSentence(
                    id = lastSentence.startTs,
                    startTs = lastSentence.startTs,
                    endTs = endTs,
                    text = transcription.text ?: "",
                    lang = transcription.lang ?: "",
                    isFinal = true,
                    translations = mergedTranslations,
                    uid = message.sttUid
                )
                sentences[sentences.lastIndex] = newSentence
                onDebug?.invoke("SYNC Final: Update [${lastSentence.startTs}-$endTs] \"${transcription.text}\"")
            } else {
                // Create new Final sentence (no pending Non-final, or last is already Final)
                val startTs = lastSentence?.endTs ?: 0

                // Validate timestamp: endTs must be > startTs
                if (endTs <= startTs) {
                    onDebug?.invoke("Discard: SYNC out-of-order Final (endTs=$endTs <= startTs=$startTs)")
                    return  // Discard out-of-order Final message
                }

                val newSentence = SttSentence(
                    id = startTs,
                    startTs = startTs,
                    endTs = endTs,
                    text = transcription.text ?: "",
                    lang = transcription.lang ?: "",
                    isFinal = true,
                    translations = translationsMap,
                    uid = message.sttUid
                )
                sentences.add(newSentence)
                onDebug?.invoke("SYNC Final: Create [$startTs-$endTs] \"${transcription.text}\"")
            }
        } else {
            // Non-final message: update or create temporary sentence (with translations)
            val lastSentence = sentences.lastOrNull()

            if (lastSentence != null && !lastSentence.isFinal) {
                // Update existing Non-final sentence
                // Only update if new timestamp >= old timestamp
                if (textTs >= lastSentence.endTs) {
                    // Merge translations with Final protection
                    val mergedTranslations = mergeTranslations(lastSentence.translations, translationsMap)

                    val newSentence = lastSentence.copy(
                        endTs = textTs,
                        text = transcription.text ?: "",
                        lang = transcription.lang ?: "",
                        translations = mergedTranslations
                    )
                    sentences[sentences.lastIndex] = newSentence
                    onDebug?.invoke("SYNC Non-Final: Update [${lastSentence.startTs}-$textTs] \"${transcription.text}\"")
                } else {
                    onDebug?.invoke("Ignore: SYNC out-of-order Non-final (textTs=$textTs < lastEndTs=${lastSentence.endTs})")
                }
                // else: ignore older out-of-order message
            } else {
                // Create new Non-final sentence
                val startTs = lastSentence?.endTs ?: 0

                // Validate timestamp: textTs must be > startTs
                if (textTs <= startTs) {
                    onDebug?.invoke("Discard: SYNC out-of-order Non-final (textTs=$textTs <= startTs=$startTs)")
                    return  // Discard out-of-order message
                }

                val newSentence = SttSentence(
                    id = startTs,
                    startTs = startTs,
                    endTs = textTs,
                    text = transcription.text ?: "",
                    lang = transcription.lang ?: "",
                    isFinal = false,
                    translations = translationsMap,
                    uid = message.sttUid
                )
                sentences.add(newSentence)
                onDebug?.invoke("SYNC Non-Final: Create [$startTs-$textTs] \"${transcription.text}\"")
            }
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

