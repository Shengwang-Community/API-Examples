package io.agora.api.example.examples.advanced.beauty

import android.content.Context
import android.util.Log
import com.effectsar.labcv.effectsdk.RenderManager
import io.agora.api.example.examples.advanced.beauty.utils.FileUtils
import io.agora.beautyapi.bytedance.ByteDanceBeautyAPI
import java.io.File

object ByteDanceBeautySDK {

    private const val TAG = "ByteDanceBeautySDK"

    private val LICENSE_NAME = "Agora_test_io.agora.entfull.licbag"
    private var storagePath = ""
    private var assetsPath = ""
    private var licensePath = ""
    private var modelsPath = ""
    var beautyNodePath = ""
    var beauty4ItemsNodePath = ""
    var reSharpNodePath = ""
    var stickerPath = ""

    private val nodesLoaded = mutableListOf<String>()

    private var beautyAPI: ByteDanceBeautyAPI? = null

    // Effect handle
    val renderManager = RenderManager()

    // Beauty configuration
    val beautyConfig = BeautyConfig()


    fun initBeautySDK(context: Context): Boolean {
        storagePath = context.getExternalFilesDir("")?.absolutePath ?: return false
        assetsPath = "beauty_bytedance"

        // copy license
        licensePath = "$storagePath/beauty_bytedance/LicenseBag.bundle/$LICENSE_NAME"
        FileUtils.copyAssets(context, "$assetsPath/LicenseBag.bundle/$LICENSE_NAME", licensePath)
        if (!File(licensePath).exists()) {
            return false
        }

        // copy models
        modelsPath = "$storagePath/beauty_bytedance/ModelResource.bundle"
        FileUtils.copyAssets(context, "$assetsPath/ModelResource.bundle", modelsPath)

        // copy beauty node
        beautyNodePath =
            "$storagePath/beauty_bytedance/ComposeMakeup.bundle/ComposeMakeup/beauty_Android_lite"
        FileUtils.copyAssets(
            context,
            "$assetsPath/ComposeMakeup.bundle/ComposeMakeup/beauty_Android_lite",
            beautyNodePath
        )

        // copy beauty 4items node
        beauty4ItemsNodePath =
            "$storagePath/beauty_bytedance/ComposeMakeup.bundle/ComposeMakeup/beauty_4Items"
        FileUtils.copyAssets(
            context,
            "$assetsPath/ComposeMakeup.bundle/ComposeMakeup/beauty_4Items",
            beauty4ItemsNodePath
        )

        // copy resharp node
        reSharpNodePath =
            "$storagePath/beauty_bytedance/ComposeMakeup.bundle/ComposeMakeup/reshape_lite"
        FileUtils.copyAssets(
            context,
            "$assetsPath/ComposeMakeup.bundle/ComposeMakeup/reshape_lite",
            reSharpNodePath
        )

        // copy stickers
        stickerPath = "$storagePath/beauty_bytedance/StickerResource.bundle/stickers"
        FileUtils.copyAssets(context, "$assetsPath/StickerResource.bundle/stickers", stickerPath)

        return true
    }

    // GL Thread
    fun initEffect(context: Context) : Boolean{
        val ret = renderManager.init(
            context,
            modelsPath, licensePath, false, false, 0
        )
        if (!checkResult("RenderManager init ", ret)) {
            return false
        }
        renderManager.useBuiltinSensor(true)
        renderManager.set3Buffer(false)
        nodesLoaded.add(beautyNodePath)
        renderManager.appendComposerNodes(
            nodesLoaded.toTypedArray()
        )
        renderManager.loadResourceWithTimeout(-1)
        beautyConfig.resume()
        return true
    }

    // GL Thread
    fun unInitEffect() {
        beautyAPI = null
        nodesLoaded.clear()
        beautyConfig.reset()
        renderManager.release()
    }

    private fun mayLoadBeauty4ItemsNode() {
        if (!nodesLoaded.contains(beauty4ItemsNodePath)) {
            nodesLoaded.add(beauty4ItemsNodePath)
            renderManager.appendComposerNodes(
                arrayOf(beauty4ItemsNodePath)
            )
            renderManager.loadResourceWithTimeout(-1)
        }
    }

    private fun mayLoadReSharpNode() {
        if (!nodesLoaded.contains(reSharpNodePath)) {
            nodesLoaded.add(reSharpNodePath)
            renderManager.appendComposerNodes(
                arrayOf(reSharpNodePath)
            )
            renderManager.loadResourceWithTimeout(-1)
        }
    }

    private fun checkResult(msg: String, ret: Int): Boolean {
        if (ret != 0 && ret != -11 && ret != 1) {
            val log = "$msg error: $ret"
            Log.e(TAG, log)
            return false
        }
        return true
    }

    internal fun setBeautyAPI(beautyAPI: ByteDanceBeautyAPI?) {
        ByteDanceBeautySDK.beautyAPI = beautyAPI
    }

    private fun runOnBeautyThread(run: () -> Unit) {
        beautyAPI?.runOnProcessThread(run) ?: run.invoke()
    }


    class BeautyConfig {

        // Smooth skin
        var smooth = 0.65f
            set(value) {
                field = value
                runOnBeautyThread {
                    renderManager.updateComposerNodes(beautyNodePath, "smooth", value)
                }
            }

        // Whitening
        var whiten = 0.5f
            set(value) {
                field = value
                runOnBeautyThread {
                    renderManager.updateComposerNodes(beautyNodePath, "whiten", value)
                }
            }

        // Ruddy
        var redden = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    renderManager.updateComposerNodes(beautyNodePath, "sharp", value)
                }
            }

        // Face thinning
        var thinFace = 0.3f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(
                        reSharpNodePath,
                        "Internal_Deform_Overall",
                        value
                    )
                }
            }

        // Eye enlarging
        var enlargeEye = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(reSharpNodePath, "Internal_Deform_Eye", value)
                }
            }

        // Cheekbone thinning
        var shrinkCheekbone = 0.3f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(
                        reSharpNodePath,
                        "Internal_Deform_Zoom_Cheekbone",
                        value
                    )
                }
            }

        // Jawbone
        var shrinkJawbone = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(
                        reSharpNodePath,
                        "Internal_Deform_Zoom_Jawbone",
                        value
                    )
                }
            }

        // Teeth whitening
        var whiteTeeth = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(
                        reSharpNodePath,
                        "BEF_BEAUTY_WHITEN_TEETH",
                        value
                    )
                }
            }

        // Forehead
        var hairlineHeight = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(
                        reSharpNodePath,
                        "Internal_Deform_Forehead",
                        value
                    )
                }
            }

        // Nose thinning
        var narrowNose = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(
                        reSharpNodePath,
                        "Internal_Deform_Nose",
                        value
                    )
                }
            }

        // Mouth shape
        var mouthSize = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(
                        reSharpNodePath,
                        "Internal_Deform_ZoomMouth",
                        value
                    )
                }
            }

        // Chin
        var chinLength = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadReSharpNode()
                    }
                    renderManager.updateComposerNodes(
                        reSharpNodePath,
                        "Internal_Deform_Chin",
                        value
                    )
                }
            }

        // Eye brightening
        var brightEye = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadBeauty4ItemsNode()
                    }
                    renderManager.updateComposerNodes(
                        beauty4ItemsNodePath,
                        "BEF_BEAUTY_BRIGHTEN_EYE",
                        value
                    )
                }
            }

        // Dark circles removal
        var darkCircles = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadBeauty4ItemsNode()
                    }
                    renderManager.updateComposerNodes(
                        beauty4ItemsNodePath,
                        "BEF_BEAUTY_REMOVE_POUCH",
                        value
                    )
                }
            }

        // Nasolabial folds removal
        var nasolabialFolds = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    if (value > 0) {
                        mayLoadBeauty4ItemsNode()
                    }
                    renderManager.updateComposerNodes(
                        beauty4ItemsNodePath,
                        "BEF_BEAUTY_SMILES_FOLDS",
                        value
                    )
                }
            }

        // Sharpen
        var sharpen = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    renderManager.updateComposerNodes(
                        beautyNodePath,
                        "sharp",
                        value
                    )
                }
            }

        // Clarity
        var clear = 0.0f
            set(value) {
                field = value
                runOnBeautyThread {
                    renderManager.updateComposerNodes(
                        beautyNodePath,
                        "clear",
                        value
                    )
                }
            }


        // Makeup
        var makeUp: MakeUpItem? = null
            set(value) {
                if (field == value) {
                    return
                }
                val oMakeUp = field
                field = value
                if (oMakeUp?.style != value?.style) {
                    if (oMakeUp != null) {
                        runOnBeautyThread {
                            val oNodePath =
                                "$storagePath/beauty_bytedance/ComposeMakeup.bundle/ComposeMakeup/style_makeup/${oMakeUp.style}"
                            renderManager.removeComposerNodes(arrayOf(oNodePath))
                        }
                    }

                    if (value != null) {
                        val nodePath =
                            "$storagePath/beauty_bytedance/ComposeMakeup.bundle/ComposeMakeup/style_makeup/${value.style}"
                        FileUtils.copyAssets(
                            value.context,
                            "$assetsPath/ComposeMakeup.bundle/ComposeMakeup/style_makeup/${value.style}",
                            nodePath
                        )
                        runOnBeautyThread {
                            renderManager.appendComposerNodes(arrayOf(nodePath))
                            renderManager.loadResourceWithTimeout(-1)
                        }
                    }
                }

                if (value != null) {
                    val nodePath =
                        "$storagePath/beauty_bytedance/ComposeMakeup.bundle/ComposeMakeup/style_makeup/${value.style}"
                    runOnBeautyThread {
                        renderManager.updateComposerNodes(
                            nodePath,
                            "Filter_ALL",
                            value.identity
                        )
                        renderManager.updateComposerNodes(
                            nodePath,
                            "Makeup_ALL",
                            value.identity
                        )
                    }
                }
            }


        // Sticker
        var sticker: String? = null
            set(value) {
                if (field == value) {
                    return
                }
                field = value
                runOnBeautyThread {
                    if (value != null) {
                        renderManager.setSticker("$stickerPath/$value")
                    } else {
                        renderManager.setSticker(null)
                    }
                }
            }

        internal fun reset() {
            smooth = 0.65f
            whiten = 0.5f
            thinFace = 0.3f
            enlargeEye = 0.0f
            redden = 0.0f
            shrinkCheekbone = 0.3f
            shrinkJawbone = 0.0f
            whiteTeeth = 0.0f
            hairlineHeight = 0.0f
            narrowNose = 0.0f
            mouthSize = 0.0f
            chinLength = 0.0f
            brightEye = 0.0f
            darkCircles = 0.0f
            nasolabialFolds = 0.0f
            sharpen = 0.0f
            clear = 0.0f

            makeUp = null
            sticker = null
        }

        internal fun resume() {
            smooth = smooth
            whiten = whiten
            thinFace = thinFace
            enlargeEye = enlargeEye
            redden = redden
            shrinkCheekbone = shrinkCheekbone
            shrinkJawbone = shrinkJawbone
            whiteTeeth = whiteTeeth
            hairlineHeight = hairlineHeight
            narrowNose = narrowNose
            mouthSize = mouthSize
            chinLength = chinLength
            brightEye = brightEye
            darkCircles = darkCircles
            nasolabialFolds = nasolabialFolds
            sharpen = sharpen
            clear = clear

            makeUp = makeUp
            sticker = sticker
        }
    }

    data class MakeUpItem(
        val context: Context,
        val style: String,
        val identity: Float
    )
}