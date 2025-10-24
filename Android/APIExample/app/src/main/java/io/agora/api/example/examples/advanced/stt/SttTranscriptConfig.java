package io.agora.api.example.examples.advanced.stt;

import static io.agora.api.example.common.model.Examples.ADVANCED;

import android.os.Bundle;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.RadioGroup;
import android.widget.Spinner;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.navigation.Navigation;

import io.agora.api.example.R;
import io.agora.api.example.annotation.Example;
import io.agora.api.example.common.BaseFragment;

/**
 * Configuration fragment for STT transcript
 * Allows user to configure channel name, translation direction, and transcript mode
 */
@Example(
        index = 27,
        group = ADVANCED,
        name = R.string.item_stt_transcript,
        actionId = R.id.action_mainFragment_to_stt_transcript_config,
        tipsId = R.string.stt_transcript
)
public class SttTranscriptConfig extends BaseFragment implements View.OnClickListener {

    private EditText etChannel;
    private RadioGroup rgTranslationDirection;
    private Spinner spinnerTranscriptMode;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_stt_transcript_config, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        etChannel = view.findViewById(R.id.et_channel);
        rgTranslationDirection = view.findViewById(R.id.rg_translation_direction);
        spinnerTranscriptMode = view.findViewById(R.id.spinner_transcript_mode);
        
        // Set default transcript mode to Async Translation (index 1)
        spinnerTranscriptMode.setSelection(1);
        
        view.findViewById(R.id.btn_join).setOnClickListener(this);
    }

    @Override
    public void onClick(View v) {
        if (v.getId() == R.id.btn_join) {
            // Check permission
            checkOrRequestPermisson((allPermissionsGranted, permissions, grantResults) -> {
                if (allPermissionsGranted) {
                    join();
                }
            });
        }
    }

    private void join() {
        String channelName = etChannel.getText().toString();
        if (TextUtils.isEmpty(channelName)) {
            Toast.makeText(getContext(), "The channel name is empty!", Toast.LENGTH_SHORT).show();
            return;
        }

        // Get translation direction based on RadioButton selection
        int checkedId = rgTranslationDirection.getCheckedRadioButtonId();
        String sourceLanguage;
        String targetLanguage;
        
        if (checkedId == R.id.rb_en_to_zh) {
            // English to Chinese
            sourceLanguage = "en-US";
            targetLanguage = "zh-CN";
        } else {
            // Chinese to English (default: rb_zh_to_en)
            sourceLanguage = "zh-CN";
            targetLanguage = "en-US";
        }

        int transcriptMode = spinnerTranscriptMode.getSelectedItemPosition();

        // Navigate to detail page with parameters
        Bundle args = new Bundle();
        args.putString(getString(R.string.key_channel_name), channelName);
        args.putString(getString(R.string.key_source_language), sourceLanguage);
        args.putInt(getString(R.string.key_stt_mode), transcriptMode);
        args.putString(getString(R.string.key_translation_language), targetLanguage);

        Navigation.findNavController(requireView()).navigate(R.id.action_stt_config_to_stt_transcript, args);
    }
}
