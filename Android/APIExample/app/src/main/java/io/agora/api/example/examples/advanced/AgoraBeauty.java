package io.agora.api.example.examples.advanced;

import static io.agora.api.example.common.model.Examples.ADVANCED;
import static io.agora.rtc2.Constants.RENDER_MODE_HIDDEN;
import static io.agora.rtc2.video.VideoEncoderConfiguration.STANDARD_BITRATE;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.RadioGroup;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.Switch;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.agora.api.example.MainApplication;
import io.agora.api.example.R;
import io.agora.api.example.annotation.Example;
import io.agora.api.example.common.BaseFragment;
import io.agora.api.example.examples.advanced.beauty.AgoraBeautySDK;
import io.agora.api.example.utils.CommonUtil;
import io.agora.api.example.utils.FileUtils;
import io.agora.api.example.utils.PermissonUtils;
import io.agora.api.example.utils.TokenUtils;
import io.agora.rtc2.ChannelMediaOptions;
import io.agora.rtc2.Constants;
import io.agora.rtc2.IRtcEngineEventHandler;
import io.agora.rtc2.RtcEngine;
import io.agora.rtc2.RtcEngineConfig;
import io.agora.rtc2.proxy.LocalAccessPointConfiguration;
import io.agora.rtc2.video.ColorEnhanceOptions;
import io.agora.rtc2.video.FaceShapeAreaOptions;
import io.agora.rtc2.video.LowLightEnhanceOptions;
import io.agora.rtc2.video.SegmentationProperty;
import io.agora.rtc2.video.VideoCanvas;
import io.agora.rtc2.video.VideoDenoiserOptions;
import io.agora.rtc2.video.VideoEncoderConfiguration;
import io.agora.rtc2.video.VirtualBackgroundSource;

/**
 * The type Agora beauty.
 */
@Example(
        index = 24,
        group = ADVANCED,
        name = R.string.item_agora_beauty,
        actionId = R.id.action_mainFragment_agora_beauty,
        tipsId = R.string.agora_beauty
)
public class AgoraBeauty extends BaseFragment implements View.OnClickListener, CompoundButton.OnCheckedChangeListener, SeekBar.OnSeekBarChangeListener, AdapterView.OnItemSelectedListener {
    private static final String TAG = AgoraBeauty.class.getSimpleName();

    private FrameLayout fl_local, fl_remote;
    private LinearLayout controlPanel;
    private Button join;
    @SuppressLint("UseSwitchCompatOrMaterialCode")
    private Switch shapeBeauty, makeUp, filter, basicBeauty, virtualBackground, exposureEnhancement, colorEnhancement, videoDenoising;
    private SeekBar sbLightness, sbRedness, sbSharpness, sbContrastStrength, sbSmoothness, sbEyePouch, sbBrightenEye, sbNasolabialFold, sbWhitenTeeth;
    private SeekBar seekColorEnhancementStrength, seekColorEnhancementSkinProtect;
    // Makeup
    private SeekBar sbBrowStrength, sbLashStrength, sbShadowStrength, sbPupilStrength, sbBlushStrength, sbLipStrength;
    private Spinner spinnerFacialStyle, spinnerWocanStyle, spinnerBrowStyle, spinnerLashStyle, spinnerShadowStyle, spinnerPupilStyle, spinnerBlushStyle, spinnerLipStyle;
    private Spinner spinnerBrowColor, spinnerLashColor, spinnerBlushColor, spinnerLipColor;
    // Beauty Shape
    private SeekBar sbFacialStrength, sbWocanStrength, sbShapeBeautifyAreaIntensity, sbShapeBeautifyStyleIntensity, sbFaceMakeupStyleIntensity, sbFilterStyleIntensity;
    private Spinner spinnerShapeBeautyArea, spinnerShapeBeautifyStyle, spinnerFaceMakeupStyle, spinnerFilterStyle;
    private EditText et_channel;
    private RadioGroup virtualBgType;
    private RtcEngine engine;
    private int myUid;
    private boolean joined = false;
    private FaceShapeAreaOptions faceShapeAreaOptions = new FaceShapeAreaOptions();

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_agora_beauty, container, false);
        return view;
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        join = view.findViewById(R.id.btn_join);
        join.setOnClickListener(this);
        et_channel = view.findViewById(R.id.et_channel);
        fl_local = view.findViewById(R.id.fl_local);
        fl_remote = view.findViewById(R.id.fl_remote);
        controlPanel = view.findViewById(R.id.controlPanel);

        // facial reshaping
        shapeBeauty = view.findViewById(R.id.switch_face_shape_beautify);
        shapeBeauty.setOnCheckedChangeListener(this);
        spinnerShapeBeautyArea = view.findViewById(R.id.spinner_shape_beauty_area);
        spinnerShapeBeautyArea.setOnItemSelectedListener(this);
        sbShapeBeautifyAreaIntensity = view.findViewById(R.id.sb_shape_beautify_area_intensity);
        sbShapeBeautifyAreaIntensity.setOnSeekBarChangeListener(this);
        spinnerShapeBeautifyStyle = view.findViewById(R.id.spinner_shape_beautify_style);
        spinnerShapeBeautifyStyle.setOnItemSelectedListener(this);
        sbShapeBeautifyStyleIntensity = view.findViewById(R.id.sb_shape_beautify_style_intensity);
        sbShapeBeautifyStyleIntensity.setOnSeekBarChangeListener(this);

        // beauty makeup
        makeUp = view.findViewById(R.id.switch_face_makeup);
        makeUp.setOnCheckedChangeListener(this);
        spinnerFaceMakeupStyle = view.findViewById(R.id.spinner_face_makeup_style);
        spinnerFaceMakeupStyle.setOnItemSelectedListener(this);
        sbFaceMakeupStyleIntensity = view.findViewById(R.id.sb_face_makeup_style_intensity);
        sbFaceMakeupStyleIntensity.setOnSeekBarChangeListener(this);

        spinnerFacialStyle = view.findViewById(R.id.spinner_facial_style);
        spinnerFacialStyle.setOnItemSelectedListener(this);
        sbFacialStrength = view.findViewById(R.id.sb_facial_strength);
        sbFacialStrength.setOnSeekBarChangeListener(this);

        spinnerWocanStyle = view.findViewById(R.id.spinner_wocan_style);
        spinnerWocanStyle.setOnItemSelectedListener(this);
        sbWocanStrength = view.findViewById(R.id.sb_wocan_strength);
        sbWocanStrength.setOnSeekBarChangeListener(this);

        spinnerBrowStyle = view.findViewById(R.id.spinner_brow_style);
        spinnerBrowStyle.setOnItemSelectedListener(this);
        spinnerBrowColor = view.findViewById(R.id.spinner_brow_color);
        spinnerBrowColor.setOnItemSelectedListener(this);
        sbBrowStrength = view.findViewById(R.id.sb_brow_strength);
        sbBrowStrength.setOnSeekBarChangeListener(this);

        spinnerLashStyle = view.findViewById(R.id.spinner_lash_style);
        spinnerLashStyle.setOnItemSelectedListener(this);
        spinnerLashColor = view.findViewById(R.id.spinner_lash_color);
        spinnerLashColor.setOnItemSelectedListener(this);
        sbLashStrength = view.findViewById(R.id.sb_lash_strength);
        sbLashStrength.setOnSeekBarChangeListener(this);

        spinnerShadowStyle = view.findViewById(R.id.spinner_shadow_style);
        spinnerShadowStyle.setOnItemSelectedListener(this);
        sbShadowStrength = view.findViewById(R.id.sb_shadow_strength);
        sbShadowStrength.setOnSeekBarChangeListener(this);

        spinnerPupilStyle = view.findViewById(R.id.spinner_pupil_style);
        spinnerPupilStyle.setOnItemSelectedListener(this);
        sbPupilStrength = view.findViewById(R.id.sb_pupil_strength);
        sbPupilStrength.setOnSeekBarChangeListener(this);

        spinnerBlushStyle = view.findViewById(R.id.spinner_blush_style);
        spinnerBlushStyle.setOnItemSelectedListener(this);
        spinnerBlushColor = view.findViewById(R.id.spinner_blush_color);
        spinnerBlushColor.setOnItemSelectedListener(this);
        sbBlushStrength = view.findViewById(R.id.sb_blush_strength);
        sbBlushStrength.setOnSeekBarChangeListener(this);

        spinnerLipStyle = view.findViewById(R.id.spinner_lip_style);
        spinnerLipStyle.setOnItemSelectedListener(this);
        spinnerLipColor = view.findViewById(R.id.spinner_lip_color);
        spinnerLipColor.setOnItemSelectedListener(this);
        sbLipStrength = view.findViewById(R.id.sb_lip_strength);
        sbLipStrength.setOnSeekBarChangeListener(this);

        // filter
        filter = view.findViewById(R.id.switch_filter);
        filter.setOnCheckedChangeListener(this);
        spinnerFilterStyle = view.findViewById(R.id.spinner_filter_style);
        spinnerFilterStyle.setOnItemSelectedListener(this);
        sbFilterStyleIntensity = view.findViewById(R.id.sb_filter_strength);
        sbFilterStyleIntensity.setOnSeekBarChangeListener(this);

        // basic beauty
        basicBeauty = view.findViewById(R.id.switch_basic_beautify);
        basicBeauty.setOnCheckedChangeListener(this);
        sbLightness = view.findViewById(R.id.lightening);
        sbLightness.setOnSeekBarChangeListener(this);
        sbRedness = view.findViewById(R.id.redness);
        sbRedness.setOnSeekBarChangeListener(this);
        sbSmoothness = view.findViewById(R.id.smoothness);
        sbSmoothness.setOnSeekBarChangeListener(this);
        sbContrastStrength = view.findViewById(R.id.sb_contrast_strength);
        sbContrastStrength.setOnSeekBarChangeListener(this);
        sbSharpness = view.findViewById(R.id.sharpness);
        sbSharpness.setOnSeekBarChangeListener(this);

        sbEyePouch = view.findViewById(R.id.sb_eye_pouch);
        sbEyePouch.setOnSeekBarChangeListener(this);
        sbBrightenEye = view.findViewById(R.id.sb_brighten_eye);
        sbBrightenEye.setOnSeekBarChangeListener(this);
        sbNasolabialFold = view.findViewById(R.id.sb_nasolabial_fold);
        sbNasolabialFold.setOnSeekBarChangeListener(this);
        sbWhitenTeeth = view.findViewById(R.id.sb_whiten_teeth);
        sbWhitenTeeth.setOnSeekBarChangeListener(this);

        // Exposure Enhancement
        exposureEnhancement = view.findViewById(R.id.switch_exposure_enhancement);
        exposureEnhancement.setOnCheckedChangeListener(this);

        // Color Enhancement
        colorEnhancement = view.findViewById(R.id.switch_color_enhancement);
        colorEnhancement.setOnCheckedChangeListener(this);
        seekColorEnhancementStrength = view.findViewById(R.id.color_enhancement_strength);
        seekColorEnhancementStrength.setOnSeekBarChangeListener(this);
        seekColorEnhancementSkinProtect = view.findViewById(R.id.color_enhancement_skin_protect);
        seekColorEnhancementSkinProtect.setOnSeekBarChangeListener(this);

        // Video Denoising
        videoDenoising = view.findViewById(R.id.switch_video_denoising);
        videoDenoising.setOnCheckedChangeListener(this);

        // Virtual Background
        virtualBackground = view.findViewById(R.id.switch_virtual_background);
        virtualBackground.setOnCheckedChangeListener(this);
        virtualBgType = view.findViewById(R.id.virtual_bg_type);
        virtualBgType.setOnCheckedChangeListener((group, checkedId) -> {
            resetVirtualBackground();
        });
    }

    private void resetVirtualBackground() {
        if (virtualBackground.isChecked()) {
            int checkedId = virtualBgType.getCheckedRadioButtonId();
            VirtualBackgroundSource backgroundSource = new VirtualBackgroundSource();
            SegmentationProperty segproperty = new SegmentationProperty();
            if (checkedId == R.id.virtual_bg_image) {
                backgroundSource.backgroundSourceType = VirtualBackgroundSource.BACKGROUND_IMG;
                String imagePath = requireContext().getExternalCacheDir().getPath();
                String imageName = "agora-logo.png";
                FileUtils.copyFilesFromAssets(getContext(), imageName, imagePath);
                backgroundSource.source = imagePath + FileUtils.SEPARATOR + imageName;
            } else if (checkedId == R.id.virtual_bg_color) {
                backgroundSource.backgroundSourceType = VirtualBackgroundSource.BACKGROUND_COLOR;
                backgroundSource.color = 0x0000EE;
            } else if (checkedId == R.id.virtual_bg_blur) {
                backgroundSource.backgroundSourceType = VirtualBackgroundSource.BACKGROUND_BLUR;
                backgroundSource.blurDegree = VirtualBackgroundSource.BLUR_DEGREE_MEDIUM;
            } else if (checkedId == R.id.virtual_bg_video) {
                backgroundSource.backgroundSourceType = VirtualBackgroundSource.BACKGROUND_VIDEO;
                backgroundSource.source = "https://agora-adc-artifacts.s3.cn-north-1.amazonaws.com.cn/resources/sample.mp4";
            }
            engine.enableVirtualBackground(true, backgroundSource, segproperty);
        } else {
            engine.enableVirtualBackground(false, null, null);
        }

    }

    @Override
    public void onActivityCreated(@Nullable Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);
        // Check if the context is valid
        Context context = getContext();
        if (context == null) {
            return;
        }
        try {
            RtcEngineConfig config = new RtcEngineConfig();
            /*
             * The context of Android Activity
             */
            config.mContext = context.getApplicationContext();
            /*
             * The App ID issued to you by Agora. See <a href="https://docs.agora.io/en/Agora%20Platform/token#get-an-app-id"> How to get the App ID</a>
             */
            config.mAppId = getString(R.string.agora_app_id);
            /* Sets the channel profile of the Agora RtcEngine.
             CHANNEL_PROFILE_COMMUNICATION(0): (Default) The Communication profile.
             Use this profile in one-on-one calls or group calls, where all users can talk freely.
             CHANNEL_PROFILE_LIVE_BROADCASTING(1): The Live-Broadcast profile. Users in a live-broadcast
             channel have a role as either broadcaster or audience. A broadcaster can both send and receive streams;
             an audience can only receive streams.*/
            config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING;
            /*
             * IRtcEngineEventHandler is an abstract class providing default implementation.
             * The SDK uses this class to report to the app on SDK runtime events.
             */
            config.mEventHandler = iRtcEngineEventHandler;
            config.mAudioScenario = Constants.AudioScenario.getValue(Constants.AudioScenario.DEFAULT);
            config.mAreaCode = ((MainApplication) getActivity().getApplication()).getGlobalSettings().getAreaCode();
            engine = RtcEngine.create(config);
            /*
             * This parameter is for reporting the usages of APIExample to agora background.
             * Generally, it is not necessary for you to set this parameter.
             */
            engine.setParameters("{"
                    + "\"rtc.report_app_scenario\":"
                    + "{"
                    + "\"appScenario\":" + 100 + ","
                    + "\"serviceType\":" + 11 + ","
                    + "\"appVersion\":\"" + RtcEngine.getSdkVersion() + "\""
                    + "}"
                    + "}");
            /* setting the local access point if the private cloud ip was set, otherwise the config will be invalid.*/
            LocalAccessPointConfiguration localAccessPointConfiguration = ((MainApplication) getActivity().getApplication()).getGlobalSettings().getPrivateCloudConfig();
            if (localAccessPointConfiguration != null) {
                // This api can only be used in the private media server scenario, otherwise some problems may occur.
                engine.setLocalAccessPoint(localAccessPointConfiguration);
            }

            //            engine.enableExtension("agora_video_filters_clear_vision", "clear_vision", true);
            //            updateExtensionProperty();
            //            updateFaceShapeBeautyStyleOptions();

            initBeautySDK();
        } catch (Exception e) {
            e.printStackTrace();
            getActivity().onBackPressed();
        }
    }

    private boolean initBeautySDK() {


        Context context = getContext();
        if (context == null) {
            return false;
        }
        return AgoraBeautySDK.INSTANCE.initBeautySDK(context, engine);
//        File externalFile = context.getExternalFilesDir("");
//        if (externalFile == null) {
//            return false;
//        }
//        String storagePath = externalFile.getAbsolutePath();
//        if (storagePath.isEmpty()) {
//            return false;
//        }
//        String modelsPath = storagePath + "/beauty_agora/beauty_material.bundle";
//        io.agora.api.example.examples.advanced.beauty.utils.FileUtils.INSTANCE.copyAssets(context, "beauty_agora/beauty_material.bundle", modelsPath);
//        videoEffectObject = engine.createVideoEffectObject(modelsPath + "/beauty_material_v2.0.0", Constants.MediaSourceType.PRIMARY_CAMERA_SOURCE);
//        return true;
    }

    // Todo Temporarily use the setFaceShapeAreaOptions method
    private void updateFaceShapeBeautyAreaOptions() {
        if (engine != null) {
            engine.setFaceShapeAreaOptions(faceShapeAreaOptions);
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        /*leaveChannel and Destroy the RtcEngine instance*/
        if (engine != null) {
            engine.leaveChannel();
        }
        AgoraBeautySDK.INSTANCE.unInitBeautySDK();
        handler.post(RtcEngine::destroy);
        engine = null;
    }

    private void joinChannel(String channelId) {
        // Check if the context is valid
        Context context = getContext();
        if (context == null) {
            return;
        }

        // Create render view by RtcEngine
        SurfaceView surfaceView = new SurfaceView(context);
        if (fl_local.getChildCount() > 0) {
            fl_local.removeAllViews();
        }
        // Add to the local container
        fl_local.addView(surfaceView, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        // Setup local video to render your local camera preview
        engine.setupLocalVideo(new VideoCanvas(surfaceView, RENDER_MODE_HIDDEN, 0));
        // Set audio route to microPhone
        engine.setDefaultAudioRoutetoSpeakerphone(true);

        /*In the demo, the default is to enter as the anchor.*/
        engine.setClientRole(Constants.CLIENT_ROLE_BROADCASTER);
        // Enable video module
        engine.enableVideo();
        // Setup video encoding configs
        engine.setVideoEncoderConfiguration(new VideoEncoderConfiguration(
                ((MainApplication) getActivity().getApplication()).getGlobalSettings().getVideoEncodingDimensionObject(),
                VideoEncoderConfiguration.FRAME_RATE.valueOf(((MainApplication) getActivity().getApplication()).getGlobalSettings().getVideoEncodingFrameRate()),
                STANDARD_BITRATE,
                VideoEncoderConfiguration.ORIENTATION_MODE.valueOf(((MainApplication) getActivity().getApplication()).getGlobalSettings().getVideoEncodingOrientation())
        ));

        /*Please configure accessToken in the string_config file.
         * A temporary token generated in Console. A temporary token is valid for 24 hours. For details, see
         *      https://docs.agora.io/en/Agora%20Platform/token?platform=All%20Platforms#get-a-temporary-token
         * A token generated at the server. This applies to scenarios with high-security requirements. For details, see
         *      https://docs.agora.io/en/cloud-recording/token_server_java?platform=Java*/
        TokenUtils.gen(requireContext(), channelId, 0, accessToken -> {
            /* Allows a user to join a channel.
             if you do not specify the uid, we will generate the uid for you*/
            ChannelMediaOptions option = new ChannelMediaOptions();
            option.autoSubscribeAudio = true;
            option.autoSubscribeVideo = true;
            option.publishMicrophoneTrack = true;
            option.publishCameraTrack = true;
            int res = engine.joinChannel(accessToken, channelId, 0, option);
            if (res != 0) {
                // Usually happens with invalid parameters
                // Error code description can be found at:
                // en: https://docs.agora.io/en/Voice/API%20Reference/java/classio_1_1agora_1_1rtc_1_1_i_rtc_engine_event_handler_1_1_error_code.html
                // cn: https://docs.agora.io/cn/Voice/API%20Reference/java/classio_1_1agora_1_1rtc_1_1_i_rtc_engine_event_handler_1_1_error_code.html
                showAlert(RtcEngine.getErrorDescription(Math.abs(res)));
                return;
            }
            // Prevent repeated entry
            join.setEnabled(false);
        });
    }

    @Override
    public void onClick(View v) {
        if (v.getId() == R.id.btn_join) {
            if (!joined) {
                CommonUtil.hideInputBoard(getActivity(), et_channel);
                // call when join button hit
                String channelId = et_channel.getText().toString();
                // Check permission
                checkOrRequestPermisson(new PermissonUtils.PermissionResultCallback() {
                    @Override
                    public void onPermissionsResult(boolean allPermissionsGranted, String[] permissions, int[] grantResults) {
                        // Permissions Granted
                        if (allPermissionsGranted) {
                            joinChannel(channelId);
                        }
                    }
                });
            } else {
                joined = false;
                /*After joining a channel, the user must call the leaveChannel method to end the
                 * call before joining another channel. This method returns 0 if the user leaves the
                 * channel and releases all resources related to the call. This method call is
                 * asynchronous, and the user has not exited the channel when the method call returns.
                 * Once the user leaves the channel, the SDK triggers the onLeaveChannel callback.
                 * A successful leaveChannel method call triggers the following callbacks:
                 *      1:The local client: onLeaveChannel.
                 *      2:The remote client: onUserOffline, if the user leaving the channel is in the
                 *          Communication channel, or is a BROADCASTER in the Live Broadcast profile.
                 * @returns 0: Success.
                 *          < 0: Failure.
                 * PS:
                 *      1:If you call the destroy method immediately after calling the leaveChannel
                 *          method, the leaveChannel process interrupts, and the SDK does not trigger
                 *          the onLeaveChannel callback.
                 *      2:If you call the leaveChannel method during CDN live streaming, the SDK
                 *          triggers the removeInjectStreamUrl method.*/
                engine.leaveChannel();
                join.setText(getString(R.string.join));
                controlPanel.setVisibility(View.INVISIBLE);
            }
        }
    }

    @SuppressLint("NonConstantResourceId")
    @Override
    public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
        switch (parent.getId()) {
            case R.id.spinner_shape_beauty_area:
                faceShapeAreaOptions.shapeArea = position - 1;
                //get origin beauty option params
                FaceShapeAreaOptions originOptions = engine.getFaceShapeAreaOptions(faceShapeAreaOptions.shapeArea);
                if (originOptions != null) {
                    faceShapeAreaOptions.shapeIntensity = originOptions.shapeIntensity;
                    sbShapeBeautifyAreaIntensity.setProgress(originOptions.shapeIntensity);
                }
                updateFaceShapeBeautyAreaOptions();
                return;
            case R.id.spinner_shape_beautify_style:
                if (shapeBeauty.isChecked()) {
                    AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyShapeStyle(spinnerShapeBeautifyStyle.getSelectedItem().toString());
                    sbShapeBeautifyStyleIntensity.setProgress(AgoraBeautySDK.INSTANCE.getBeautyConfig().getBeautyShapeStrength());
                } else {
                    AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyShapeStyle(null);
                }

                return;
            case R.id.spinner_face_makeup_style:
                if (makeUp.isChecked()) {
                    AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyMakeupStyle(spinnerFaceMakeupStyle.getSelectedItem().toString());
                    sbFaceMakeupStyleIntensity.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getBeautyMakeupStrength() * 10));
                } else {
                    AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyMakeupStyle(null);
                }
                return;
            case R.id.spinner_filter_style:
                if (filter.isChecked()) {
                    AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyFilter(spinnerFilterStyle.getSelectedItem().toString());
                    sbFilterStyleIntensity.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getFilterStrength() * 10));
                } else {
                    AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyFilter(null);
                }
                return;
            case R.id.spinner_facial_style:
                int facialStyleValue = 0;
                if (position == 1) {
                    facialStyleValue = 2;
                } else if (position == 2) {
                    facialStyleValue = 3;
                } else if (position == 3) {
                    facialStyleValue = 5;
                } else if (position == 4) {
                    facialStyleValue = 6;
                }
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setFacialStyle(facialStyleValue);
                return;
            case R.id.spinner_wocan_style:
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setWocanStyle(position);
                return;
            case R.id.spinner_brow_style:
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setBrowStyle(position);
                return;
            case R.id.spinner_brow_color:
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setBrowColor(position);
                return;
            case R.id.spinner_lash_style:
                int lashStyleValue = 0;
                if (position == 1) {
                    lashStyleValue = 3;
                } else if (position == 2) {
                    lashStyleValue = 5;
                }
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setLashStyle(lashStyleValue);
                return;
            case R.id.spinner_lash_color:
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setLashColor(position);
                return;
            case R.id.spinner_shadow_style:
                int shadowStyleValue = 0;
                if (position == 1) {
                    shadowStyleValue = 1;
                } else if (position == 2) {
                    shadowStyleValue = 6;
                }
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setShadowStyle(shadowStyleValue);
                return;
            case R.id.spinner_pupil_style:
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setPupilStyle(position);
                return;
            case R.id.spinner_blush_style:
                int blushStyleValue = 0;
                if (position == 1) {
                    blushStyleValue = 1;
                } else if (position == 2) {
                    blushStyleValue = 2;
                } else if (position == 3) {
                    blushStyleValue = 4;
                } else if (position == 4) {
                    blushStyleValue = 9;
                }
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setBlushStyle(blushStyleValue);
                return;
            case R.id.spinner_blush_color:
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setBlushColor(position);
                return;
            case R.id.spinner_lip_style:
                int lipStyleValue = 0;
                if (position == 1) {
                    lipStyleValue = 1;
                } else if (position == 2) {
                    lipStyleValue = 2;
                } else if (position == 3) {
                    lipStyleValue = 3;
                } else if (position == 4) {
                    lipStyleValue = 6;
                }
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setLipStyle(lipStyleValue);
                return;
            case R.id.spinner_lip_color:
                AgoraBeautySDK.INSTANCE.getBeautyConfig().setLipColor(position);
                return;
            default: {

            }
        }
    }

    @Override
    public void onNothingSelected(AdapterView<?> parent) {

    }

    @Override
    public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
        int id = buttonView.getId();
        if (id == R.id.switch_face_shape_beautify) {
            if (isChecked && !engine.isFeatureAvailableOnDevice(Constants.FEATURE_VIDEO_BEAUTY_EFFECT)) {
                buttonView.setChecked(false);
                Toast.makeText(requireContext(), R.string.feature_unavailable, Toast.LENGTH_SHORT).show();
                return;
            }
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyShapeStyle(spinnerShapeBeautifyStyle.getSelectedItem().toString());
        } else if (id == makeUp.getId()) {
            if (isChecked && !engine.isFeatureAvailableOnDevice(Constants.FEATURE_VIDEO_BEAUTY_EFFECT)) {
                buttonView.setChecked(false);
                Toast.makeText(requireContext(), R.string.feature_unavailable, Toast.LENGTH_SHORT).show();
                return;
            }
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyMakeupStyle(spinnerFaceMakeupStyle.getSelectedItem().toString());
        } else if (id == filter.getId()) {
            if (isChecked && !engine.isFeatureAvailableOnDevice(Constants.FEATURE_VIDEO_BEAUTY_EFFECT)) {
                buttonView.setChecked(false);
                Toast.makeText(requireContext(), R.string.feature_unavailable, Toast.LENGTH_SHORT).show();
                return;
            }
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyFilter(spinnerFilterStyle.getSelectedItem().toString());
        } else if (id == basicBeauty.getId()) {
            if (isChecked && !engine.isFeatureAvailableOnDevice(Constants.FEATURE_VIDEO_BEAUTY_EFFECT)) {
                buttonView.setChecked(false);
                Toast.makeText(requireContext(), R.string.feature_unavailable, Toast.LENGTH_SHORT).show();
                return;
            }
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBasicBeauty(isChecked);
            sbSmoothness.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getSmoothness() * 10));
            sbLightness.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getLightness() * 10));
            sbRedness.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getLightness() * 10));
            sbContrastStrength.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getContrastStrength() * 10));
            sbSharpness.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getSharpness() * 10));

            sbEyePouch.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getEyePouch() * 10));
            sbBrightenEye.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getBrightenEye() * 10));
            sbNasolabialFold.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getNasolabialFold() * 10));
            sbWhitenTeeth.setProgress((int) (AgoraBeautySDK.INSTANCE.getBeautyConfig().getWhitenTeeth() * 10));
        } else if (id == exposureEnhancement.getId()) {
            LowLightEnhanceOptions options = new LowLightEnhanceOptions();
            options.lowlightEnhanceLevel = LowLightEnhanceOptions.LOW_LIGHT_ENHANCE_LEVEL_FAST;
            options.lowlightEnhanceMode = LowLightEnhanceOptions.LOW_LIGHT_ENHANCE_AUTO;
            engine.setLowlightEnhanceOptions(isChecked, options);
        } else if (id == colorEnhancement.getId()) {
            setColorEnhancement(isChecked);
        } else if (id == virtualBackground.getId()) {
            if (isChecked && !engine.isFeatureAvailableOnDevice(Constants.FEATURE_VIDEO_VIRTUAL_BACKGROUND)) {
                buttonView.setChecked(false);
                Toast.makeText(requireContext(), R.string.feature_unavailable, Toast.LENGTH_SHORT).show();
                return;
            }
            resetVirtualBackground();
        } else if (id == videoDenoising.getId()) {
            VideoDenoiserOptions options = new VideoDenoiserOptions();
            options.denoiserLevel = VideoDenoiserOptions.VIDEO_DENOISER_LEVEL_HIGH_QUALITY;
            options.denoiserMode = VideoDenoiserOptions.VIDEO_DENOISER_AUTO;
            engine.setVideoDenoiserOptions(isChecked, options);
        }
    }

    private double colorEnhancementSkinProtect = 1.0;
    private double colorEnhancementStrength = 0.5;

    private void setColorEnhancement(boolean isChecked) {
        ColorEnhanceOptions options = new ColorEnhanceOptions();
        options.strengthLevel = (float) colorEnhancementStrength;
        options.skinProtectLevel = (float) colorEnhancementSkinProtect;
        engine.setColorEnhanceOptions(isChecked, options);
    }

    @Override
    public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
        Log.d(TAG, "onProgressChanged " + seekBar.getId() + " " + seekBar.getProgress());
    }

    @Override
    public void onStartTrackingTouch(SeekBar seekBar) {
        Log.d(TAG, "onStartTrackingTouch " + seekBar.getId() + " " + seekBar.getProgress());
    }

    @Override
    public void onStopTrackingTouch(SeekBar seekBar) {
        Log.d(TAG, "onStopTrackingTouch " + seekBar.getId() + " " + seekBar.getProgress());
        int progress = seekBar.getProgress();
        float value = ((float) progress) / 10;
        if (seekBar.getId() == sbShapeBeautifyAreaIntensity.getId()) {
            faceShapeAreaOptions.shapeIntensity = progress;
            updateFaceShapeBeautyAreaOptions();
        } else if (seekBar.getId() == sbShapeBeautifyStyleIntensity.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyShapeStrength(progress);
        } else if (seekBar.getId() == sbFaceMakeupStyleIntensity.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBeautyMakeupStrength(value);
        } else if (seekBar.getId() == sbFacialStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setFacialStrength(value);
        } else if (seekBar.getId() == sbWocanStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setWocanStrength(value);
        } else if (seekBar.getId() == sbBrowStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBrowStrength(value);
        } else if (seekBar.getId() == sbLashStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setLashStrength(value);
        } else if (seekBar.getId() == sbShadowStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setShadowStrength(value);
        } else if (seekBar.getId() == sbPupilStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setPupilStrength(value);
        } else if (seekBar.getId() == sbBlushStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBlushStrength(value);
        } else if (seekBar.getId() == sbLipStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setLipStrength(value);
        } else if (seekBar.getId() == sbFilterStyleIntensity.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setFilterStrength(value);
        } else if (seekBar.getId() == sbLightness.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setLightness(value);
        } else if (seekBar.getId() == sbRedness.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setRedness(value);
        } else if (seekBar.getId() == sbSharpness.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setSharpness(value);
        } else if (seekBar.getId() == sbSmoothness.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setSmoothness(value);
        } else if (seekBar.getId() == sbContrastStrength.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setContrastStrength(value);
        } else if (seekBar.getId() == sbEyePouch.getId()) {
            // face_buffing_option Basic Beauty Extension
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setEyePouch(value);
        } else if (seekBar.getId() == sbBrightenEye.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setBrightenEye(value);
        } else if (seekBar.getId() == sbNasolabialFold.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setNasolabialFold(value);
        } else if (seekBar.getId() == sbWhitenTeeth.getId()) {
            AgoraBeautySDK.INSTANCE.getBeautyConfig().setWhitenTeeth(value);
        } else if (seekBar.getId() == seekColorEnhancementStrength.getId()) {
            colorEnhancementStrength = value;
            setColorEnhancement(colorEnhancement.isChecked());
        } else if (seekBar.getId() == seekColorEnhancementSkinProtect.getId()) {
            colorEnhancementSkinProtect = value;
            setColorEnhancement(colorEnhancement.isChecked());
        }
    }


    /**
     * IRtcEngineEventHandler is an abstract class providing default implementation.
     * The SDK uses this class to report to the app on SDK runtime events.
     */
    private final IRtcEngineEventHandler iRtcEngineEventHandler = new IRtcEngineEventHandler() {
        /**
         * Error code description can be found at:
         * en: https://api-ref.agora.io/en/video-sdk/android/4.x/API/class_irtcengineeventhandler.html#callback_irtcengineeventhandler_onerror
         * cn: https://docs.agora.io/cn/video-call-4.x/API%20Reference/java_ng/API/class_irtcengineeventhandler.html#callback_irtcengineeventhandler_onerror
         */
        @Override
        public void onError(int err) {
            Log.w(TAG, String.format("onError code %d message %s", err, RtcEngine.getErrorDescription(err)));
        }

        /**Occurs when a user leaves the channel.
         * @param stats With this callback, the application retrieves the channel information,
         *              such as the call duration and statistics.*/
        @Override
        public void onLeaveChannel(RtcStats stats) {
            super.onLeaveChannel(stats);
            Log.i(TAG, String.format("local user %d leaveChannel!", myUid));
            showLongToast(String.format("local user %d leaveChannel!", myUid));
        }

        /**Occurs when the local user joins a specified channel.
         * The channel name assignment is based on channelName specified in the joinChannel method.
         * If the uid is not specified when joinChannel is called, the server automatically assigns a uid.
         * @param channel Channel name
         * @param uid User ID
         * @param elapsed Time elapsed (ms) from the user calling joinChannel until this callback is triggered*/
        @Override
        public void onJoinChannelSuccess(String channel, int uid, int elapsed) {
            Log.i(TAG, String.format("onJoinChannelSuccess channel %s uid %d", channel, uid));
            showLongToast(String.format("onJoinChannelSuccess channel %s uid %d", channel, uid));
            myUid = uid;
            joined = true;
            handler.post(new Runnable() {
                @Override
                public void run() {
                    join.setEnabled(true);
                    join.setText(getString(R.string.leave));
                    controlPanel.setVisibility(View.VISIBLE);
                }
            });
        }

        /**Since v2.9.0.
         * This callback indicates the state change of the remote audio stream.
         * PS: This callback does not work properly when the number of users (in the Communication profile) or
         *     broadcasters (in the Live-broadcast profile) in the channel exceeds 17.
         * @param uid ID of the user whose audio state changes.
         * @param state State of the remote audio
         *   REMOTE_AUDIO_STATE_STOPPED(0): The remote audio is in the default state, probably due
         *              to REMOTE_AUDIO_REASON_LOCAL_MUTED(3), REMOTE_AUDIO_REASON_REMOTE_MUTED(5),
         *              or REMOTE_AUDIO_REASON_REMOTE_OFFLINE(7).
         *   REMOTE_AUDIO_STATE_STARTING(1): The first remote audio packet is received.
         *   REMOTE_AUDIO_STATE_DECODING(2): The remote audio stream is decoded and plays normally,
         *              probably due to REMOTE_AUDIO_REASON_NETWORK_RECOVERY(2),
         *              REMOTE_AUDIO_REASON_LOCAL_UNMUTED(4) or REMOTE_AUDIO_REASON_REMOTE_UNMUTED(6).
         *   REMOTE_AUDIO_STATE_FROZEN(3): The remote audio is frozen, probably due to
         *              REMOTE_AUDIO_REASON_NETWORK_CONGESTION(1).
         *   REMOTE_AUDIO_STATE_FAILED(4): The remote audio fails to start, probably due to
         *              REMOTE_AUDIO_REASON_INTERNAL(0).
         * @param reason The reason of the remote audio state change.
         *   REMOTE_AUDIO_REASON_INTERNAL(0): Internal reasons.
         *   REMOTE_AUDIO_REASON_NETWORK_CONGESTION(1): Network congestion.
         *   REMOTE_AUDIO_REASON_NETWORK_RECOVERY(2): Network recovery.
         *   REMOTE_AUDIO_REASON_LOCAL_MUTED(3): The local user stops receiving the remote audio
         *               stream or disables the audio module.
         *   REMOTE_AUDIO_REASON_LOCAL_UNMUTED(4): The local user resumes receiving the remote audio
         *              stream or enables the audio module.
         *   REMOTE_AUDIO_REASON_REMOTE_MUTED(5): The remote user stops sending the audio stream or
         *               disables the audio module.
         *   REMOTE_AUDIO_REASON_REMOTE_UNMUTED(6): The remote user resumes sending the audio stream
         *              or enables the audio module.
         *   REMOTE_AUDIO_REASON_REMOTE_OFFLINE(7): The remote user leaves the channel.
         * @param elapsed Time elapsed (ms) from the local user calling the joinChannel method
         *                  until the SDK triggers this callback.*/
        @Override
        public void onRemoteAudioStateChanged(int uid, int state, int reason, int elapsed) {
            super.onRemoteAudioStateChanged(uid, state, reason, elapsed);
            Log.i(TAG, "onRemoteAudioStateChanged->" + uid + ", state->" + state + ", reason->" + reason);
        }

        /**Since v2.9.0.
         * Occurs when the remote video state changes.
         * PS: This callback does not work properly when the number of users (in the Communication
         *     profile) or broadcasters (in the Live-broadcast profile) in the channel exceeds 17.
         * @param uid ID of the remote user whose video state changes.
         * @param state State of the remote video:
         *   REMOTE_VIDEO_STATE_STOPPED(0): The remote video is in the default state, probably due
         *              to REMOTE_VIDEO_STATE_REASON_LOCAL_MUTED(3), REMOTE_VIDEO_STATE_REASON_REMOTE_MUTED(5),
         *              or REMOTE_VIDEO_STATE_REASON_REMOTE_OFFLINE(7).
         *   REMOTE_VIDEO_STATE_STARTING(1): The first remote video packet is received.
         *   REMOTE_VIDEO_STATE_DECODING(2): The remote video stream is decoded and plays normally,
         *              probably due to REMOTE_VIDEO_STATE_REASON_NETWORK_RECOVERY (2),
         *              REMOTE_VIDEO_STATE_REASON_LOCAL_UNMUTED(4), REMOTE_VIDEO_STATE_REASON_REMOTE_UNMUTED(6),
         *              or REMOTE_VIDEO_STATE_REASON_AUDIO_FALLBACK_RECOVERY(9).
         *   REMOTE_VIDEO_STATE_FROZEN(3): The remote video is frozen, probably due to
         *              REMOTE_VIDEO_STATE_REASON_NETWORK_CONGESTION(1) or REMOTE_VIDEO_STATE_REASON_AUDIO_FALLBACK(8).
         *   REMOTE_VIDEO_STATE_FAILED(4): The remote video fails to start, probably due to
         *              REMOTE_VIDEO_STATE_REASON_INTERNAL(0).
         * @param reason The reason of the remote video state change:
         *   REMOTE_VIDEO_STATE_REASON_INTERNAL(0): Internal reasons.
         *   REMOTE_VIDEO_STATE_REASON_NETWORK_CONGESTION(1): Network congestion.
         *   REMOTE_VIDEO_STATE_REASON_NETWORK_RECOVERY(2): Network recovery.
         *   REMOTE_VIDEO_STATE_REASON_LOCAL_MUTED(3): The local user stops receiving the remote
         *               video stream or disables the video module.
         *   REMOTE_VIDEO_STATE_REASON_LOCAL_UNMUTED(4): The local user resumes receiving the remote
         *               video stream or enables the video module.
         *   REMOTE_VIDEO_STATE_REASON_REMOTE_MUTED(5): The remote user stops sending the video
         *               stream or disables the video module.
         *   REMOTE_VIDEO_STATE_REASON_REMOTE_UNMUTED(6): The remote user resumes sending the video
         *               stream or enables the video module.
         *   REMOTE_VIDEO_STATE_REASON_REMOTE_OFFLINE(7): The remote user leaves the channel.
         *   REMOTE_VIDEO_STATE_REASON_AUDIO_FALLBACK(8): The remote media stream falls back to the
         *               audio-only stream due to poor network conditions.
         *   REMOTE_VIDEO_STATE_REASON_AUDIO_FALLBACK_RECOVERY(9): The remote media stream switches
         *               back to the video stream after the network conditions improve.
         * @param elapsed Time elapsed (ms) from the local user calling the joinChannel method until
         *               the SDK triggers this callback.*/
        @Override
        public void onRemoteVideoStateChanged(int uid, int state, int reason, int elapsed) {
            super.onRemoteVideoStateChanged(uid, state, reason, elapsed);
            Log.i(TAG, "onRemoteVideoStateChanged->" + uid + ", state->" + state + ", reason->" + reason);
        }

        /**Occurs when a remote user (Communication)/host (Live Broadcast) joins the channel.
         * @param uid ID of the user whose audio state changes.
         * @param elapsed Time delay (ms) from the local user calling joinChannel/setClientRole
         *                until this callback is triggered.*/
        @Override
        public void onUserJoined(int uid, int elapsed) {
            super.onUserJoined(uid, elapsed);
            Log.i(TAG, "onUserJoined->" + uid);
            showLongToast(String.format("user %d joined!", uid));
            /*Check if the context is correct*/
            Context context = getContext();
            if (context == null) {
                return;
            } else {
                handler.post(() -> {
                    if (fl_remote.getChildCount() > 0) {
                        fl_remote.removeAllViews();
                    }
                    /*Display remote video stream*/
                    SurfaceView surfaceView = null;
                    // Create render view by RtcEngine
                    surfaceView = new SurfaceView(context);
                    surfaceView.setZOrderMediaOverlay(true);
                    // Add to the remote container
                    fl_remote.addView(surfaceView, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                    // Setup remote video to render
                    engine.setupRemoteVideo(new VideoCanvas(surfaceView, RENDER_MODE_HIDDEN, uid));
                });
            }
        }

        /**Occurs when a remote user (Communication)/host (Live Broadcast) leaves the channel.
         * @param uid ID of the user whose audio state changes.
         * @param reason Reason why the user goes offline:
         *   USER_OFFLINE_QUIT(0): The user left the current channel.
         *   USER_OFFLINE_DROPPED(1): The SDK timed out and the user dropped offline because no data
         *              packet was received within a certain period of time. If a user quits the
         *               call and the message is not passed to the SDK (due to an unreliable channel),
         *               the SDK assumes the user dropped offline.
         *   USER_OFFLINE_BECOME_AUDIENCE(2): (Live broadcast only.) The client role switched from
         *               the host to the audience.*/
        @Override
        public void onUserOffline(int uid, int reason) {
            Log.i(TAG, String.format("user %d offline! reason:%d", uid, reason));
            showLongToast(String.format("user %d offline! reason:%d", uid, reason));
            handler.post(new Runnable() {
                @Override
                public void run() {
                    /*Clear render view
                     Note: The video will stay at its last frame, to completely remove it you will need to
                     remove the SurfaceView from its parent*/
                    engine.setupRemoteVideo(new VideoCanvas(null, RENDER_MODE_HIDDEN, uid));
                }
            });
        }
    };

}
