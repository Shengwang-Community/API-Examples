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
     * 1. If existing translation is Final, it's immutable (ignore new data)
     * 2. If existing is Non-Final:
     *    - Overwrite if new data is Final
     *    - Overwrite if new data is Non-Final but has newer/equal timestamp
     */
    private fun mergeTranslations(
        existing: Map<String, TranslationData>,
        new: Map<String, TranslationData>
    ): Map<String, TranslationData> {
        val merged = existing.toMutableMap()
        new.forEach { (lang, newData) ->
            val existingData = merged[lang]
            // Determine whether to update or add the translation based on state and timestamp
            val addOrReplace = if (existingData == null) {
                // Case 1: No existing translation, add new one
                true
            } else if (existingData.isFinal) {
                // Case 2: Existing translation is Final, do not overwrite (Final is immutable)
                false
            } else { 
                // Case 3: Existing is Non-Final. 
                // Update if new data is Final OR new timestamp is newer/equal
                newData.isFinal || newData.ts >= existingData.ts
            }
            
            if (addOrReplace) {
                merged[lang] = newData
            }
        }
        return merged
    }

    /**
     * Insert sentence in order by sentenceId (timestamp, always increasing)
     * Optimized for the common case where sentences arrive in order.
     * @param sentence The sentence to insert
     */
    private fun insertSentenceInOrder(sentence: SttSentence) {
        // Fast path: if the list is empty or the new sentence is newer than the last one, append directly.
        if (sentences.isEmpty() || sentence.id > sentences.last().id) {
            sentences.add(sentence)
            return
        }

        // Binary search for insertion position
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

    /**
     * Process transcription message (ASYNC mode)
     * Updates existing sentence or creates new one based on sentenceId.
     * - Final sentences are immutable.
     * - Non-Final sentences can be updated if timestamp is newer.
     */
    private fun processTranscription(message: SttMessage) {
        val transcription = message.sttTranscription ?: return
        val sentenceId = message.sttSentenceId
        val textTs = message.sttTextTs

        // Find existing sentence by sentenceId
        val existingIndex = sentences.indexOfFirst { it.id == sentenceId }

        if (existingIndex >= 0) {
            // Update existing sentence
            val existingSentence = sentences[existingIndex]
            
            // 1. Check: Final is immutable
            if (existingSentence.isFinal) {
                onDebug?.invoke("Ignore: Existing Final sentence [sentenceId=$sentenceId]")
                return
            }

            // 2. Check: Non-Final updates must respect timestamp (unless new data is Final)
            if (!transcription.isFinal && textTs < existingSentence.textTs) {
                onDebug?.invoke(
                    "Ignore: Non-Final with smaller textTs cannot overwrite larger " +
                            "[sentenceId=$sentenceId, existing=${existingSentence.textTs}, new=$textTs]"
                )
                return
            }

            // 3. Execute Update (Unified)
            val updatedSentence = existingSentence.copy(
                textTs = textTs,
                text = transcription.text ?: "",
                lang = transcription.lang ?: "",
                isFinal = transcription.isFinal
                // Keep existing translations, don't overwrite
            )
            sentences[existingIndex] = updatedSentence
            onDebug?.invoke(
                "Transcript ${if (transcription.isFinal) "Final" else "Non-Final"}: Update [sentenceId=$sentenceId, textTs=$textTs] \"${transcription.text}\""
            )

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

    /**
     * Process translation message (ASYNC mode)
     * Updates existing sentence with new translations.
     * - Creates placeholder sentence if translation arrives before transcription.
     * - Merges translations with existing ones (Final translations are immutable).
     */
    private fun processTranslation(message: SttMessage) {
        val translations = message.sttTranslations ?: return
        val sentenceId = message.sttSentenceId
        val textTs = message.sttTextTs

        // 1. Build new translations map
        val newTranslations = mutableMapOf<String, TranslationData>()
        translations.forEach { translation ->
            newTranslations[translation.sttTranslationLang ?: ""] = TranslationData(
                text = translation.sttTranslationText ?: "",
                ts = textTs,
                isFinal = translation.isFinal
            )
        }

        // Find the sentence by sentenceId
        val targetIndex = sentences.indexOfFirst { it.id == sentenceId }

        if (targetIndex < 0) {
            // Case 1: Translation arrived before Transcription (Out-of-order)
            // Action: Create a placeholder sentence to store the translation.
            // The actual text will be filled when Transcription arrives later.
            val newSentence = SttSentence(
                id = sentenceId,
                textTs = textTs,
                text = "", // Temporarily empty
                lang = "", // Unknown
                isFinal = false, // Unknown state, default to false
                uid = message.sttUid,
                translations = newTranslations
            )
            insertSentenceInOrder(newSentence)
            onDebug?.invoke("Translation (Early Arrival): Created placeholder [sentenceId=$sentenceId]")
        } else {
            val targetSentence = sentences[targetIndex]

            // Merge with existing translations (with Final protection)
            val mergedTranslations = mergeTranslations(targetSentence.translations, newTranslations)

            val updatedSentence = targetSentence.copy(
                translations = mergedTranslations
            )

            // Replace the sentence
            sentences[targetIndex] = updatedSentence
            onDebug?.invoke("Translation: [sentenceId=$sentenceId, textTs=${updatedSentence.textTs}] \"${updatedSentence.translations}\"")
        }
    }

    /**
     * Process translation message (SYNC mode)
     * Message contains both transcription and translation.
     * - Updates transcription text and state.
     * - Merges translations with existing ones.
     * - Final sentences are immutable.
     */
    private fun processTranslationSync(message: SttMessage) {
        val transcription = message.sttTranscription ?: return
        val translations = message.sttTranslations ?: return
        val sentenceId = message.sttSentenceId
        val textTs = message.sttTextTs

        // 1. Build translations map
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

            // 1. Check: Final is immutable
            if (existingSentence.isFinal) {
                onDebug?.invoke("Ignore: Existing Final sentence [sentenceId=$sentenceId]")
                return
            }

            // 2. Check: Non-Final updates must respect timestamp (unless new data is Final)
            if (!transcription.isFinal && textTs < existingSentence.textTs) {
                onDebug?.invoke(
                    "Ignore: Non-Final with smaller textTs cannot overwrite larger " +
                            "[sentenceId=$sentenceId, existing=${existingSentence.textTs}, new=$textTs]"
                )
                return
            }

            // 3. Execute Update (Unified)
            // Merge translations (with Final protection)
            val mergedTranslations = mergeTranslations(existingSentence.translations, translationsMap)

            val updatedSentence = existingSentence.copy(
                textTs = textTs,
                text = transcription.text ?: "",
                lang = transcription.lang ?: "",
                isFinal = transcription.isFinal,
                translations = mergedTranslations
            )
            sentences[existingIndex] = updatedSentence
            onDebug?.invoke(
                "SYNC ${if (transcription.isFinal) "Final" else "Non-Final"}: Update [sentenceId=$sentenceId, textTs=$textTs] \"${transcription.text}\""
            )

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
