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
    private lateinit var loadingView: View

    private val _channel: MethodChannel = MethodChannel(messenger, Constants.CHANNEL_ID)
    private val controller: ARController
    private val methodCallHandler: ARMethodCallHandler

    init {
        // Initializations & DI:
        val sceneHandler = ARSceneHandler(activity, lifecycle)
        controller = ARController(this, sceneHandler)
        lifecycle.addObserver(controller)
        methodCallHandler = ARMethodCallHandler(controller)
        _channel.setMethodCallHandler(this)
        generateAndroidViews(context)
    }

    private fun generateAndroidViews(context: Context) {
        rootView = LayoutInflater.from(context)
            .inflate(R.layout.view_ar, null, false) as FrameLayout
        loadingView = rootView.findViewById(R.id.situm_ar_loading_view)
    }

    override fun getView(): View {
        return rootView
    }

    override fun dispose() {
        unload()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val arguments = (call.arguments ?: emptyMap<String, Any>()) as Map<String, Any>
        methodCallHandler.handle(call.method, arguments, result)
    }

    fun load() {
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
        // This call is critical to avoid crashes going into background and back again.
        sceneView.removeLifecycle()
        Log.d(TAG, "Lifecycle assigned, AR session should start now.")
    }

    fun unload() {
        sceneView.pause()
        sceneView.destroy()
        rootView.removeView(sceneView)
    }
}