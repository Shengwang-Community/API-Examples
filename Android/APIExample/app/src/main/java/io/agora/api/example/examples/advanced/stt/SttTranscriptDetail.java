package io.agora.api.example.examples.advanced.stt;

import android.content.Context;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import org.json.JSONObject;

import io.agora.api.example.BuildConfig;
import io.agora.api.example.MainApplication;
import io.agora.api.example.R;
import io.agora.api.example.common.BaseFragment;
import io.agora.api.example.utils.TokenUtils;
import io.agora.rtc2.ChannelMediaOptions;
import io.agora.rtc2.Constants;
import io.agora.rtc2.DataStreamMsgHandlerConfig;
import io.agora.rtc2.IRtcEngineEventHandler;
import io.agora.rtc2.RtcEngine;
import io.agora.rtc2.RtcEngineConfig;
import io.agora.rtc2.stt.SttMessage;
import io.agora.rtc2.stt.SttTranslation;

/**
 * Detail page for STT transcript
 */
public class SttTranscriptDetail extends BaseFragment implements View.OnClickListener {

    /**
     * Transcript only mode (no translation)
     */
    public static final int STT_MODE_NONE_TRANSLATION = 0;

    /**
     * Transcript with async translation mode
     */
    public static final int STT_MODE_ASYNC_TRANSLATION = 1;

    /**
     * Transcript with sync translation mode
     */
    public static final int STT_MODE_SYNC_TRANSLATION = 2;

    private static final String TAG = "SttTranscript";

    private RecyclerView rvTranscript;
    private TextView tvEmptyState;
    private TextView tvChannelInfo;
    private TextView tvOnlineCount;
    private Button btnMute;
    private Button btnLeave;

    private RtcEngine engine;
    private TranscriptAdapter adapter;
    private Handler handler;
    private SttNetworkManager networkManager;
    private SttMessageRenderer messageRenderer;

    private String channelName;
    private String sourceLanguage;
    private int transcriptMode;
    private String targetTranslationLanguage;
    private String agentId; // Store agent ID for stop request
    private boolean joined = false;
    private boolean isMuted = false;
    private int botUid = 201128; // Default bot UID for STT
    private int onlineUserCount = 0; // Track online users (including self)

    private void writeLog(String tag, String message) {
        handler.post(() -> {
            if (engine != null) {
                if (BuildConfig.DEBUG) {
                    Log.d(tag, message);
                }
                engine.writeLog(Constants.LogLevel.LOG_LEVEL_INFO.ordinal(), tag + " " + message);
            }
        });
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_stt_transcript_detail, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        handler = new Handler(Looper.getMainLooper());
        networkManager = new SttNetworkManager();
        messageRenderer = new SttMessageRenderer(s -> {
            writeLog(TAG, s);
            return null;
        });

        // Get parameters from arguments
        Bundle args = getArguments();
        if (args != null) {
            channelName = args.getString(getString(R.string.key_channel_name));
            sourceLanguage = args.getString(getString(R.string.key_source_language), "zh-CN");
            transcriptMode = args.getInt(getString(R.string.key_stt_mode), STT_MODE_ASYNC_TRANSLATION); // Default: Transcript + Async Translation
            targetTranslationLanguage = args.getString(getString(R.string.key_translation_language), "en-US");
        }

        // Set processing mode based on transcript mode
        // Mode 0: Transcript Only - ASYNC without translations
        // Mode 1: Transcript + Async Translation - ASYNC with translations (default)
        // Mode 2: Transcript + Sync Translation - SYNC (filters non-translated messages)
        if (transcriptMode == STT_MODE_SYNC_TRANSLATION) {
            messageRenderer.setProcessingMode(SttProcessingMode.SYNC);
        } else {
            messageRenderer.setProcessingMode(SttProcessingMode.ASYNC);
        }

        // Initialize views
        tvChannelInfo = view.findViewById(R.id.tv_channel_info);
        tvOnlineCount = view.findViewById(R.id.tv_online_count);
        rvTranscript = view.findViewById(R.id.rv_transcript);
        tvEmptyState = view.findViewById(R.id.tv_empty_state);
        btnMute = view.findViewById(R.id.btn_mute);
        btnLeave = view.findViewById(R.id.btn_leave);

        btnMute.setOnClickListener(this);
        btnLeave.setOnClickListener(this);

        // Setup RecyclerView
        adapter = new TranscriptAdapter();
        rvTranscript.setLayoutManager(new LinearLayoutManager(getContext()));
        rvTranscript.setAdapter(adapter);

        // Update channel info
        updateChannelInfo();
    }

    @Override
    public void onActivityCreated(@Nullable Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);

        Context context = getContext();
        if (context == null || engine != null) {
            return;
        }

        try {
            // Initialize RTC Engine
            RtcEngineConfig config = new RtcEngineConfig();
            config.mContext = context.getApplicationContext();
            config.mAppId = getString(R.string.agora_app_id);
            config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING;
            config.mEventHandler = iRtcEngineEventHandler;
            config.mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT;
            config.mAreaCode = ((MainApplication) requireActivity().getApplication()).getGlobalSettings().getAreaCode();

            engine = RtcEngine.create(config);
            engine.setParameters("{\"rtc.log_external_input\": true}");

            joinChannel();
        } catch (Exception e) {
            Log.e(TAG, "Failed to initialize RtcEngine", e);
            Toast.makeText(context, "Failed to initialize: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private void joinChannel() {
        if (engine == null) {
            return;
        }

        // Set client role to broadcaster
        engine.setClientRole(Constants.CLIENT_ROLE_BROADCASTER);

        // Enable audio
        engine.enableAudio();

        // Set audio route to speaker
        engine.setDefaultAudioRoutetoSpeakerphone(true);

        // Configure channel media options
        ChannelMediaOptions option = new ChannelMediaOptions();
        option.autoSubscribeAudio = true;
        option.autoSubscribeVideo = false;
        option.publishMicrophoneTrack = true;
        option.publishCameraTrack = false;

        // Join channel with token
        TokenUtils.gen(requireContext(), channelName, 0, ret -> {
            int res = engine.joinChannel(ret, channelName, 0, option);
            if (res != 0) {
                Log.e(TAG, "Failed to join channel: " + res);
                handler.post(() -> {
                    Toast.makeText(getContext(), "Failed to join channel: " + res, Toast.LENGTH_SHORT).show();
                });
            }
        });
    }

    @Override
    public void onClick(View v) {
        int id = v.getId();
        if (id == R.id.btn_mute) {
            toggleMute();
        } else if (id == R.id.btn_leave) {
            leaveChannel();
        }
    }

    private void toggleMute() {
        if (engine == null) {
            return;
        }

        isMuted = !isMuted;
        engine.muteLocalAudioStream(isMuted);
        btnMute.setText(isMuted ? R.string.unmute : R.string.mute);

        Toast.makeText(getContext(), isMuted ? "Muted" : "Unmuted", Toast.LENGTH_SHORT).show();
    }

    private void leaveChannel() {
        // Stop STT transcript first
        stopSttTranscript();
        unregisterDataStreamMsgHandler();

        if (engine != null && joined) {
            engine.leaveChannel();
            joined = false;
        }

        if (getActivity() != null) {
            getActivity().onBackPressed();
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();

        stopSttTranscript();
        unregisterDataStreamMsgHandler();

        if (engine != null) {
            engine.leaveChannel();
            RtcEngine.destroy();
            engine = null;
        }
    }

    /**
     * RTC Engine event handler
     */
    private final IRtcEngineEventHandler iRtcEngineEventHandler = new IRtcEngineEventHandler() {
        @Override
        public void onJoinChannelSuccess(String channel, int uid, int elapsed) {
            Log.d(TAG, "onJoinChannelSuccess: " + channel + ", uid: " + uid);
            joined = true;
            onlineUserCount = 1; // Self joined

            handler.post(() -> {
                updateOnlineCount();
                Toast.makeText(getContext(), "Joined channel successfully", Toast.LENGTH_SHORT).show();

                // Start STT transcript
                startSttTranscript();
            });
        }

        @Override
        public void onUserJoined(int uid, int elapsed) {
            Log.d(TAG, "onUserJoined: " + uid);
            onlineUserCount++;
            handler.post(() -> {
                updateOnlineCount();
                Toast.makeText(getContext(), "User " + uid + " joined", Toast.LENGTH_SHORT).show();
            });
        }

        @Override
        public void onUserOffline(int uid, int reason) {
            Log.d(TAG, "onUserOffline: " + uid + ", reason: " + reason);
            onlineUserCount = Math.max(1, onlineUserCount - 1); // Keep at least 1 (self)
            handler.post(() -> {
                updateOnlineCount();
                Toast.makeText(getContext(), "User " + uid + " left", Toast.LENGTH_SHORT).show();
            });
        }

        @Override
        public void onLeaveChannel(RtcStats stats) {
            Log.d(TAG, "onLeaveChannel");
            joined = false;
        }

        @Override
        public void onError(int err) {
            Log.e(TAG, "onError: " + err);
            handler.post(() -> {
                Toast.makeText(getContext(), "Error: " + err, Toast.LENGTH_SHORT).show();
            });
        }

        // Note: STT data is now handled by onSttMessage callback in registerDataStreamMsgHandler
        // instead of onStreamMessage
    };

    /**
     * Register data stream message handler for STT
     */
    private void registerDataStreamMsgHandler() {
        if (engine == null) {
            return;
        }

        DataStreamMsgHandlerConfig config = new DataStreamMsgHandlerConfig();
        config.enableSttParser = true;  // Enable STT parser
        config.sttUid = botUid;  // Bot UID that sends STT data

        engine.registerDataStreamMsgHandler((channel, msg) -> {
            // Process STT message
            handleSttMessage(msg);

            return 0;
        }, config);

        Log.d(TAG, "Data stream message handler registered");
    }

    /**
     * Unregister data stream message handler
     */
    private void unregisterDataStreamMsgHandler() {
        if (engine == null) {
            return;
        }

        DataStreamMsgHandlerConfig config = new DataStreamMsgHandlerConfig();
        config.enableSttParser = true;
        config.sttUid = botUid;
        engine.registerDataStreamMsgHandler(null, config);

        Log.d(TAG, "Data stream message handler unregistered");
    }

    /**
     * Handle STT message data using SttMessageRenderer
     *
     * @param msg SttMessage from the SDK
     */
    private void handleSttMessage(SttMessage msg) {
        if (msg == null || messageRenderer == null) {
            return;
        }

        // Log incoming message - original data for debugging (combined)
        StringBuilder logMsg = new StringBuilder();
        logMsg.append("Original Message - Type: ").append(msg.sttMessageType)
                .append(", TextTs: ").append(msg.sttTextTs)
                .append(", UID: ").append(msg.sttUid);

        if (msg.sttTranscription != null) {
            logMsg.append("\n  Transcript: ").append(msg.sttTranscription.text)
                    .append(", Lang: ").append(msg.sttTranscription.lang)
                    .append(", isFinal: ").append(msg.sttTranscription.isFinal);
        }

        if (msg.sttTranslations != null) {
            for (SttTranslation trans : msg.sttTranslations) {
                logMsg.append("\n  Translation: ").append(trans.sttTranslationText)
                        .append(", Lang: ").append(trans.sttTranslationLang)
                        .append(", isFinal: ").append(trans.isFinal);
            }
        }

        writeLog(TAG, logMsg.toString());

        // Process message with renderer
        java.util.List<SttSentence> sentences = messageRenderer.processMessage(msg);

        // Update UI on main thread
        final java.util.List<SttSentence> finalSentences = sentences;
        handler.post(() -> {
            adapter.updateSentences(finalSentences);
            updateEmptyState();
            if (adapter.getItemCount() > 0) {
                rvTranscript.smoothScrollToPosition(adapter.getItemCount() - 1);
            }
        });
    }

    /**
     * Start STT transcript service
     */
    private void startSttTranscript() {
        if (networkManager == null) {
            return;
        }

        String appId = getString(R.string.agora_app_id);

        // Source and target languages are already in correct format (e.g., "zh-CN", "en-US")
        // No conversion needed since they come directly from SttTranscriptConfig

        // Mode 0: Transcript Only - request translation but filter in UI
        // Mode 1: Transcript + Async Translation - ASYNC with translations (default)
        // Mode 2: Transcript + Sync Translation - SYNC (filters non-translated messages)
        // Note: Always request translation from API, filtering happens at processing/display level
        boolean enableTranslation = transcriptMode > STT_MODE_NONE_TRANSLATION;

        Log.d(TAG, "Starting STT - Mode: " + transcriptMode + ", Source: " + sourceLanguage + ", Target: " + targetTranslationLanguage);

        networkManager.startTranscript(appId, channelName, String.valueOf(botUid), new String[]{sourceLanguage}, enableTranslation,
                new String[]{targetTranslationLanguage}, new SttNetworkManager.ResponseCallback() {
                    @Override
                    public void onSuccess(String response) {
                        Log.d(TAG, "STT started successfully: " + response);

                        // Parse response structure: {"code":0,"data":{"agent_id":"...","create_ts":...,"status":"RUNNING"},"msg":"success"}
                        try {
                            JSONObject jsonObject = new JSONObject(response);
                            int code = jsonObject.optInt("code", -1);
                            String msg = jsonObject.optString("msg", "");

                            if (code == 0) {
                                JSONObject data = jsonObject.optJSONObject("data");
                                if (data != null) {
                                    agentId = data.optString("agent_id", null);
                                    handler.post(() -> {
                                        registerDataStreamMsgHandler();
                                        Toast.makeText(getContext(), "STT started: " + msg, Toast.LENGTH_LONG).show();
                                    });
                                } else {
                                    handler.post(() -> {
                                        Toast.makeText(getContext(), "Invalid response: missing data", Toast.LENGTH_LONG).show();
                                    });
                                }
                            } else {
                                handler.post(() -> {
                                    Toast.makeText(getContext(), "API error: " + msg, Toast.LENGTH_LONG).show();
                                });
                            }
                        } catch (Exception e) {
                            handler.post(() -> {
                                Toast.makeText(getContext(), "Failed to parse response", Toast.LENGTH_LONG).show();
                            });
                        }
                    }

                    @Override
                    public void onFailure(String error) {
                        Log.e(TAG, "Failed to start STT: " + error);
                        handler.post(() -> {
                            Toast.makeText(getContext(), "Failed to start STT: " + error, Toast.LENGTH_LONG).show();
                        });
                    }
                });
    }

    /**
     * Stop STT transcript service
     */
    private void stopSttTranscript() {
        if (networkManager == null || agentId == null) {
            return;
        }

        String appId = getString(R.string.agora_app_id);

        networkManager.stopTranscript(appId, agentId, new SttNetworkManager.ResponseCallback() {
            @Override
            public void onSuccess(String response) {
                Log.d(TAG, "STT stopped successfully: " + response);

                // Parse response to check code
                try {
                    JSONObject jsonObject = new JSONObject(response);
                    int code = jsonObject.optInt("code", -1);
                    if (code == 0) {
                        agentId = null;
                    }
                } catch (Exception e) {
                    // Still clear agentId even if parsing fails
                    agentId = null;
                }
            }

            @Override
            public void onFailure(String error) {
                Log.e(TAG, "Failed to stop STT: " + error);
            }
        });
    }

    private void updateEmptyState() {
        if (adapter.getItemCount() > 0) {
            tvEmptyState.setVisibility(View.GONE);
        } else {
            tvEmptyState.setVisibility(View.VISIBLE);
        }
    }

    private void updateChannelInfo() {
        if (tvChannelInfo != null && channelName != null) {
            tvChannelInfo.setText(getString(R.string.stt_channel, channelName));
        }
    }

    private void updateOnlineCount() {
        if (tvOnlineCount != null) {
            tvOnlineCount.setText(getString(R.string.stt_online_count, onlineUserCount));
        }
    }
}

