package com.situm.flutter.ar.situm_ar

import com.situm.flutter.ar.situm_ar.scene.ARSceneHandler

class ARController(
    private val arView: SitumARPlatformView,
    private val arSceneHandler: ARSceneHandler,
) {
    companion object {
        const val TAG = "Situm> AR>"
    }

    private var isLoaded = false
    private var isLoading = false

    fun load() {
        if (isLoaded || isLoading) {
            return
        }
        isLoading = true
        arView.showLoading(true)
        arView.load()
        // Now arView.sceneView is safe to use even if we change the behavior to instantiate it in
        // the load() call.
        arSceneHandler.setupSceneView(arView.sceneView)
        isLoaded = true
        isLoading = false
        arView.showLoading(false)
    }

    fun unload() {
        arView.pause()
        arView.unload()
        isLoading = false
        isLoaded = false
    }

    fun resume() {
        arView.resume()
    }

    fun pause() {
        arView.pause()
    }
}