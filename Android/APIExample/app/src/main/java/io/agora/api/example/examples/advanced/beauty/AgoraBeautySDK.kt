package io.agora.api.example.examples.advanced.beauty

import android.content.Context
import io.agora.api.example.examples.advanced.beauty.utils.FileUtils.copyAssets
import io.agora.rtc2.Constants
import io.agora.rtc2.IVideoEffectObject
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.video.FaceShapeAreaOptions

object AgoraBeautySDK {
    private const val TAG = "AgoraBeautySDK"
    private var rtcEngine: RtcEngine? = null
    private var videoEffectObject: IVideoEffectObject? = null
    private val faceShapeAreaOptions = FaceShapeAreaOptions()

    enum class UserInterfaceOption {
        None,
        Natural,
        Female,
        Male,
        XueJie,
        XueMei,
        YuanSheng,
        LengBai,
        NenBai
    }

    // 美颜配置
    val beautyConfig = BeautyConfig()

    fun initBeautySDK(context: Context, rtcEngine: RtcEngine): Boolean {
        rtcEngine.enableExtension("agora_video_filters_clear_vision", "clear_vision", true)
        val storagePath = context.getExternalFilesDir("")?.absolutePath ?: return false
        val modelsPath = "$storagePath/beauty_agora/beauty_material.bundle"
        copyAssets(context, "beauty_agora/beauty_material.bundle", modelsPath)
        videoEffectObject = rtcEngine.createVideoEffectObject(
            "$modelsPath/beauty_material_v2.0.0",
            Constants.MediaSourceType.PRIMARY_CAMERA_SOURCE
        )
        return true
    }

    fun unInitBeautySDK() {
        rtcEngine?.let {
            videoEffectObject?.let { vEffectObject ->
                it.destroyVideoEffectObject(vEffectObject)
            }
            it.enableExtension(
                "agora_video_filters_clear_vision",
                "clear_vision",
                false,
                Constants.MediaSourceType.PRIMARY_CAMERA_SOURCE
            )
        }
        beautyConfig.reset()
    }

    /**
     * 获取基础美颜部位值
     */
    private fun getBasicBeautyOption(key: String): Float {
        return videoEffectObject?.getVideoEffectFloatParam("beauty_effect_option", key) ?: 0f
    }

    /**
     * 获取基础美颜扩展部位值
     */
    private fun getExtensionBeautyOption(key: String): Float {
        return videoEffectObject?.getVideoEffectFloatParam("face_buffing_option", key) ?: 0f
    }

    private fun getVideoEffectIntParam(option: String, key: String): Int {
        return videoEffectObject?.getVideoEffectIntParam(option, key) ?: 0
    }

    private fun getVideoEffectFloatParam(option: String, key: String): Float {
        return videoEffectObject?.getVideoEffectFloatParam(option, key) ?: 0f
    }

    private fun setVideoEffectBoolParam(option: String, key: String): Boolean {
        return videoEffectObject?.getVideoEffectBoolParam(option, key) ?: false
    }

    class BeautyConfig {

        /**
         * @param option face_shape_area_option:
         *               face_shape_beauty_option:
         *               beauty_effect_option: Basic beauty
         *               face_buffing_option: Basic beauty extension. if beauty_effect_option close, face_buffing_option will have no effect.
         *               makeup_options: makeup
         *               style_makeup_option：makeup style intensity
         *               filter_effect_option: filter
         * @param key
         * @param value
         */

        //================================ basic beauty  start ========================
        var basicBeauty = videoEffectObject?.getVideoEffectBoolParam("beauty_effect_option", "enable") ?: false
            set(value) {
                field = value
                val vEffectObject = videoEffectObject ?: return
                vEffectObject.setVideoEffectBoolParam("beauty_effect_option", "enable", value)
            }

        var smoothness = videoEffectObject?.getVideoEffectFloatParam("beauty_effect_option", "smoothness") ?: 0.5f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("beauty_effect_option", "smoothness", value)
            }

        var lightness = videoEffectObject?.getVideoEffectFloatParam("beauty_effect_option", "lightness") ?: 0.7f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("beauty_effect_option", "lightness", value)
            }

        var redness = videoEffectObject?.getVideoEffectFloatParam("beauty_effect_option", "redness") ?: 0.5f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("beauty_effect_option", "redness", value)
            }

        var sharpness = videoEffectObject?.getVideoEffectFloatParam("beauty_effect_option", "sharpness") ?: 0.9f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("beauty_effect_option", "sharpness", value)
            }

        var contrast = videoEffectObject?.getVideoEffectIntParam("beauty_effect_option", "contrast") ?: 1
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("beauty_effect_option", "contrast", value)
            }

        var contrastStrength =
            videoEffectObject?.getVideoEffectFloatParam("beauty_effect_option", "contrast_strength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("beauty_effect_option", "contrast_strength", value)
            }
        //================================ basic beauty  end ========================

        //================================ extension beauty  start ========================
        var eyePouch = videoEffectObject?.getVideoEffectFloatParam("face_buffing_option", "eye_pouch") ?: 0.5f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("face_buffing_option", "eye_pouch", value)
            }

        var brightenEye = videoEffectObject?.getVideoEffectFloatParam("face_buffing_option", "brighten_eye") ?: 0.9f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("face_buffing_option", "brighten_eye", value)
            }

        var nasolabialFold =
            videoEffectObject?.getVideoEffectFloatParam("face_buffing_option", "nasolabial_fold") ?: 0.7f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("face_buffing_option", "nasolabial_fold", value)
            }

        var whitenTeeth = videoEffectObject?.getVideoEffectFloatParam("face_buffing_option", "whiten_teeth") ?: 0.7f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("face_buffing_option", "whiten_teeth", value)
            }
        //================================ extension beauty  end ========================


        //================================ beauty shape start ========================
        var beautyShapeStyle: String? = null
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                if (value == null) {
                    effectObj.removeVideoEffect(IVideoEffectObject.VIDEO_EFFECT_NODE_ID.BEAUTY.value)
                } else {
                    effectObj.addOrUpdateVideoEffect(
                        IVideoEffectObject.VIDEO_EFFECT_NODE_ID.BEAUTY.value, value
                    )
                }
            }

        // 美型风格强度
        var beautyShapeStrength =
            videoEffectObject?.getVideoEffectIntParam("face_shape_beauty_option", "intensity") ?: 50
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("face_shape_beauty_option", "intensity", value)
            }

        // 美型头部区域强度
        var faceShapeAreaHeadScale = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_HEADSCALE
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        var faceShapeAreaForehead = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_FOREHEAD
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        var faceShapeAreaFaceContour = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_FACECONTOUR
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        var faceShapeAreaFaceLength = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_FACELENGTH
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        var faceShapeAreaFaceWidth = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_FACEWIDTH
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        // 美型眼部参数设置
        var faceShapeAreaEyeScale = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_EYESCALE
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        var faceShapeAreaEyeDistance = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_EYEDISTANCE
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        var faceShapeAreaEyelid = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_EYELID
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        // 美型鼻子参数设置
        var faceShapeAreaNoseLength = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_NOSELENGTH
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        var faceShapeAreaNoseWing = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_NOSEWING
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        // 美型嘴唇参数设置
        var faceShapeAreaMouthScale = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_MOUTHSCALE
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        var faceShapeAreaMouthLip = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_MOUTHLIP
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        // 美型眉毛参数设置
        var faceShapeAreaEyebrowPosition = 50
            set(value) {
                field = value
                val rtcEngine = rtcEngine ?: return
                faceShapeAreaOptions.shapeArea = FaceShapeAreaOptions.FACE_SHAPE_AREA_EYEBROWPOSITION
                rtcEngine.setFaceShapeAreaOptions(faceShapeAreaOptions)
            }

        //================================ beauty shape end ========================

        // 美妆
        var beautyMakeupStyle: String? = null
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                if (value == null) {
                    effectObj.removeVideoEffect(IVideoEffectObject.VIDEO_EFFECT_NODE_ID.STYLE_MAKEUP.value)
                } else {
                    effectObj.addOrUpdateVideoEffect(
                        IVideoEffectObject.VIDEO_EFFECT_NODE_ID.STYLE_MAKEUP.value, value
                    )
                }
            }

        // 美妆风格强度
        var beautyMakeupStrength =
            videoEffectObject?.getVideoEffectFloatParam("style_makeup_option", "styleIntensity") ?: 0.5f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("style_makeup_option", "styleIntensity", value)
            }

        // 面部类型
        var facialStyle = videoEffectObject?.getVideoEffectIntParam("makeup_options", "facialStyle") ?: 5
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "facialStyle", value)
            }

        // 面部强度
        var facialStrength = videoEffectObject?.getVideoEffectFloatParam("makeup_options", "facialStrength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("makeup_options", "facialStrength", value)
            }

        // 卧蚕类型
        var wocanStyle = 3
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "wocanStyle", value)
            }

        // 卧蚕强度
        var wocanStrength = videoEffectObject?.getVideoEffectFloatParam("makeup_options", "wocanStrength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("makeup_options", "wocanStrength", value)
            }

        // 眉毛类型
        var browStyle = 2
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "browStyle", value)
            }

        // 眉毛颜色
        var browColor = 2
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "browColor", value)
            }

        // 眉毛强度
        var browStrength = videoEffectObject?.getVideoEffectFloatParam("makeup_options", "browStrength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("makeup_options", "browStrength", value)
            }

        // 眼睫毛类型
        var lashStyle = videoEffectObject?.getVideoEffectIntParam("makeup_options", "lashStyle") ?: 5
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "lashStyle", value)
            }

        // 眼睫毛颜色
        var lashColor =  videoEffectObject?.getVideoEffectIntParam("makeup_options", "lashColor") ?: 1
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "lashColor", value)
            }

        // 眼睫毛强度
        var lashStrength = videoEffectObject?.getVideoEffectFloatParam("makeup_options", "lashStrength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("makeup_options", "lashStrength", value)
            }

        // 眼影类型
        var shadowStyle = videoEffectObject?.getVideoEffectIntParam("makeup_options", "shadowStyle") ?: 6
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "shadowStyle", value)
            }

        // 眼影强度
        var shadowStrength = videoEffectObject?.getVideoEffectFloatParam("makeup_options", "shadowStrength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("makeup_options", "shadowStrength", value)
            }

        // 瞳孔类型
        var pupilStyle = videoEffectObject?.getVideoEffectIntParam("makeup_options", "pupilStyle") ?: 2
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "pupilStyle", value)
            }

        // 瞳孔强度
        var pupilStrength = videoEffectObject?.getVideoEffectFloatParam("makeup_options", "pupilStrength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("makeup_options", "pupilStrength", value)
            }

        // 腮红类型
        var blushStyle = videoEffectObject?.getVideoEffectIntParam("makeup_options", "blushStyle") ?: 2
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "blushStyle", value)
            }

        // 腮红颜色
        var blushColor = videoEffectObject?.getVideoEffectIntParam("makeup_options", "blushColor") ?: 5
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "blushColor", value)
            }

        // 腮红强度
        var blushStrength = videoEffectObject?.getVideoEffectFloatParam("makeup_options", "blushStrength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("makeup_options", "blushStrength", value)
            }

        // 唇彩类型
        var lipStyle = videoEffectObject?.getVideoEffectIntParam("makeup_options", "lipStyle") ?: 2
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "lipStyle", value)
            }

        // 唇彩颜色
        var lipColor = videoEffectObject?.getVideoEffectIntParam("makeup_options", "lipColor") ?: 5
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectIntParam("makeup_options", "lipColor", value)
            }

        // 唇彩强度
        var lipStrength = videoEffectObject?.getVideoEffectFloatParam("makeup_options", "lipStrength") ?: 1.0f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("makeup_options", "lipStrength", value)
            }

        // 滤镜
        var beautyFilter: String? = null
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                if (value == null) {
                    effectObj.removeVideoEffect(IVideoEffectObject.VIDEO_EFFECT_NODE_ID.FILTER.value)
                } else {
                    effectObj.addOrUpdateVideoEffect(
                        IVideoEffectObject.VIDEO_EFFECT_NODE_ID.FILTER.value, value
                    )
                }
            }

        // 滤镜强度
        var filterStrength =  videoEffectObject?.getVideoEffectFloatParam("filter_effect_option", "strength") ?: 0.5f
            set(value) {
                field = value
                val effectObj = videoEffectObject ?: return
                effectObj.setVideoEffectFloatParam("filter_effect_option", "strength", value)
            }

        internal fun reset() {
            smoothness = 0.5f
            lightness = 0.7f
            redness = 0.5f
            contrast = 1
            sharpness = 0.0f
            contrastStrength = 0.5f
            eyePouch = 0.5f
            brightenEye = 0.9f
            nasolabialFold = 0.5f
            whitenTeeth = 0.5f

            beautyShapeStyle = null
            beautyMakeupStyle = null
            beautyFilter = null
        }

        internal fun resume() {
            filterStrength = filterStrength


        }
    }
}