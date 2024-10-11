package com.situm.flutter.ar.situm_ar

import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.situm.flutter.ar.situm_ar.scene.ARSceneHandler

/**
 * Plugin controller.
 */
class ARController(
    private val arView: SitumARPlatformView,
    private val arSceneHandler: ARSceneHandler,
    private val arMethodCallSender: ARMethodCallSender,
) : DefaultLifecycleObserver {
    companion object {
        const val TAG = "Situm> AR>"
    }

    private var isLoaded = false
    private var isLoading = false

    fun load() {
        Log.d(TAG, "Situm> AR> L&U> CALLED LOAD")
        if (isLoaded || isLoading) {
            return
        }
        Log.d(TAG, "\tSitum> AR> L&U> ACTUALLY LOADED")
        isLoading = true
        arView.load()
        // Now arView.sceneView is safe to use even if we change the behavior to instantiate it in
        // the load() call.
        arSceneHandler.setupSceneView(arView.sceneView)
        isLoaded = true
        isLoading = false
    }

    fun unload() {
        Log.d(TAG, "Situm> AR> L&U> CALLED UNLOAD")
        if (isLoaded) {
            Log.d(TAG, "\tSitum> AR> L&U> ACTUALLY UNLOADED")
            arSceneHandler.unload()
            arView.unload()
            isLoading = false
            isLoaded = false
        }
    }

    fun resume() {
        Log.d(TAG, "Situm> AR> L&U> CALLED RESUME")
        arView.load()
    }

    fun pause() {
        Log.d(TAG, "Situm> AR> L&U> CALLED PAUSE")
        arView.unload()
    }

    // -- Android Lifecycle:

    override fun onResume(owner: LifecycleOwner) {
        Log.d(TAG, "Situm> AR> L&U> Lifecycle> onResume")
    }

    override fun onPause(owner: LifecycleOwner) {
        Log.d(TAG, "Situm> AR> L&U> Lifecycle> onPause")
    }

    override fun onStop(owner: LifecycleOwner) {
        Log.d(TAG, "Situm> AR> L&U> Lifecycle> onStop")
        if (isLoaded) {
            arMethodCallSender.sendArGoneRequired()
        }
    }
}