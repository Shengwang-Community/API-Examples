package io.agora.api.example.examples.advanced.stt;

import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.agora.api.example.R;

/**
 * Adapter for displaying STT transcription sentences
 */
public class TranscriptAdapter extends RecyclerView.Adapter<TranscriptAdapter.ViewHolder> {
    /**
     * Alpha value for non-final transcription text
     */
    private static final float ALPHA_NON_FINAL = 0.7f;

    /**
     * Alpha value for final transcription text
     */
    private static final float ALPHA_FINAL = 1.0f;

    private List<SttSentence> sentences = new ArrayList<>();

    /**
     * Update the list of sentences to display
     *
     * @param newSentences The new list of STT sentences
     */
    public void updateSentences(List<SttSentence> newSentences) {
        this.sentences = new ArrayList<>(newSentences);
        notifyDataSetChanged();
    }

    /**
     * Clear all sentences from the adapter
     */
    public void clear() {
        sentences.clear();
        notifyDataSetChanged();
    }

    /**
     * Get the number of items in the adapter
     *
     * @return The number of items
     */
    public int getItemCount() {
        return sentences.size();
    }

    /**
     * Create a new ViewHolder for the item at the given position
     *
     * @param parent   The parent view group
     * @param viewType The view type of the item
     * @return A new ViewHolder
     */
    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_stt_transcript, parent, false);
        return new ViewHolder(view);
    }

    /**
     * Bind the data to the ViewHolder at the given position
     *
     * @param holder   The ViewHolder to bind the data to
     * @param position The position of the item to bind
     */
    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        SttSentence sentence = sentences.get(position);

        // Set timestamp - show timestamp
        String timeInfo = "SentenceId: " + sentence.getId();
        holder.tvTimestamp.setText(timeInfo);

        // Set language tag (source language)
        String langTag = sentence.getLang().toUpperCase();
        if (!sentence.isFinal()) {
            // Append indicator for non-final
            holder.tvTranscription.setAlpha(ALPHA_NON_FINAL);
        } else {
            holder.tvTranscription.setAlpha(ALPHA_FINAL);
        }
        holder.tvLanguage.setText(langTag);
        holder.tvLanguage.setVisibility(View.VISIBLE);
        // Set transcription text
        holder.tvTranscription.setText(sentence.getText());
        
        // Set translations (display all translation languages)
        holder.llTranslations.removeAllViews();
        Map<String, TranslationData> translations = sentence.getTranslations();
        if (!translations.isEmpty()) {
            holder.llTranslations.setVisibility(View.VISIBLE);
            
            for (Map.Entry<String, TranslationData> entry : translations.entrySet()) {
                String lang = entry.getKey();
                String text = entry.getValue().getText();
                
                if (!TextUtils.isEmpty(text)) {
                    // Create translation view dynamically
                    View translationView = LayoutInflater.from(holder.itemView.getContext())
                            .inflate(R.layout.item_stt_translation_row, holder.llTranslations, false);
                    
                    TextView tvLang = translationView.findViewById(R.id.tv_translation_lang);
                    TextView tvText = translationView.findViewById(R.id.tv_translation_text);
                    
                    tvLang.setText(lang.toUpperCase());
                    tvText.setText(text);
                    
                    holder.llTranslations.addView(translationView);
                }
            }
        } else {
            holder.llTranslations.setVisibility(View.GONE);
        }
    }

    /**
     * ViewHolder for the item at the given position
     */
    static class ViewHolder extends RecyclerView.ViewHolder {
        TextView tvTimestamp;
        TextView tvLanguage;
        TextView tvTranscription;
        LinearLayout llTranslations;

        ViewHolder(@NonNull View itemView) {
            super(itemView);
            tvTimestamp = itemView.findViewById(R.id.tv_timestamp);
            tvLanguage = itemView.findViewById(R.id.tv_language);
            tvTranscription = itemView.findViewById(R.id.tv_transcript);
            llTranslations = itemView.findViewById(R.id.ll_translations);
        }
    }
}

