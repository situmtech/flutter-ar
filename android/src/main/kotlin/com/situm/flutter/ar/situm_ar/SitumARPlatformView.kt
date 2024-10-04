package com.situm.flutter.ar.situm_ar

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import androidx.lifecycle.Lifecycle
import com.google.ar.core.Config
import com.situm.flutter.ar.situm_ar.scene.ARSceneHandler
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView

class SitumARPlatformView(
    private val context: Context,
    activity: Activity,
    private val lifecycle: Lifecycle,
    messenger: BinaryMessenger,
) : PlatformView, MethodCallHandler {

    companion object {
        const val TAG = "Situm> AR>"
    }

    lateinit var sceneView: CustomARSceneView
    private lateinit var rootView: FrameLayout

    private val flutterMethodChannel: MethodChannel = MethodChannel(messenger, Constants.CHANNEL_ID)
    private val arController: ARController
    private val arMethodCallHandler: ARMethodCallHandler

    init {
        // Initializations & DI:
        val arMethodCallSender = ARMethodCallSender(flutterMethodChannel)
        val sceneHandler = ARSceneHandler(activity, lifecycle)
        arController = ARController(this, sceneHandler, arMethodCallSender)
        arMethodCallHandler = ARMethodCallHandler(arController)
        flutterMethodChannel.setMethodCallHandler(this)
        generateAndroidViews(context)
    }

    private fun generateAndroidViews(context: Context) {
        rootView = LayoutInflater.from(context)
            .inflate(R.layout.view_ar, null, false) as FrameLayout
    }

    override fun getView(): View {
        return rootView
    }

    override fun dispose() {
        unload()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val arguments = (call.arguments ?: emptyMap<String, Any>()) as Map<String, Any>
        arMethodCallHandler.handle(call.method, arguments, result)
    }

    fun load() {
        lifecycle.addObserver(arController)
        sceneView = CustomARSceneView(context)
        sceneView.sessionConfiguration = { session, config ->
            config.depthMode =
                if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    Config.DepthMode.AUTOMATIC
                } else {
                    Config.DepthMode.DISABLED
                }
            config.instantPlacementMode = Config.InstantPlacementMode.DISABLED
            config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
        }
        // This call will make the AR visible:
        sceneView.lifecycle = lifecycle
        rootView.addView(sceneView)
        Log.d(TAG, "Lifecycle assigned, AR session should start now.")
    }

    fun unload() {
        sceneView.pause()
        // sceneView.destroy() will be called anyway after removeView(sceneView). destroy() was
        // modified to avoid multiple crashes.
        rootView.removeView(sceneView)
        lifecycle.removeObserver(arController)
    }
}