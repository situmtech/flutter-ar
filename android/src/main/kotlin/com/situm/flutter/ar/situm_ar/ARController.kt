package com.situm.flutter.ar.situm_ar

import android.os.Looper
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.situm.flutter.ar.situm_ar.scene.ARSceneHandler
import com.situm.flutter.ar.situm_ar.scene.ARSceneHandlerCallback
import es.situm.sdk.SitumSdk
import es.situm.sdk.communication.CommunicationConfigImpl
import es.situm.sdk.configuration.network.NetworkOptions
import es.situm.sdk.configuration.network.NetworkOptionsImpl
import es.situm.sdk.model.cartography.BuildingInfo
import es.situm.sdk.utils.Handler

/**
 * Plugin controller.
 */
class ARController(
    private val arView: SitumARPlatformView,
    private val arSceneHandler: ARSceneHandler,
    private val arMethodCallSender: ARMethodCallSender,
) : DefaultLifecycleObserver, ARSceneHandlerCallback {
    companion object {
        const val TAG = "Situm> AR>"
    }


    private var isLoaded = false
    private var isLoading = false

    private val handler = android.os.Handler(Looper.getMainLooper())

    private val updateDebugInfoRunnable = object : Runnable {
        override fun run() {
            if (isLoaded && arSceneHandler.isDebugMode()) {
                updateDebugInfo()
                handler.postDelayed(this, 1000) // Vuelve a ejecutar después de 1 segundo
            }
        }
    }


    fun load(buildingIdentifier: String) {
        Log.d(TAG, "Situm> AR> L&U> CALLED LOAD")
        if (isLoaded || isLoading) {
            return
        }
        Log.d(TAG, "\tSitum> AR> L&U> ACTUALLY LOADED")
        isLoading = true
        SitumSdk.communicationManager().fetchBuildingInfo(
            buildingIdentifier,
            CommunicationConfigImpl(
                NetworkOptionsImpl.Builder()
                    .setCacheStrategy(NetworkOptions.CacheStrategy.TIMED_CACHE)
                    .build()
            ),
            object : Handler<BuildingInfo> {
                override fun onSuccess(obtained: BuildingInfo?) {
                    arSceneHandler.setBuildingInfo(obtained as BuildingInfo)
                    Log.w(TAG, "> Situm: fetch Building info, Success")
                }

                override fun onFailure(error: es.situm.sdk.error.Error?) {
                    Log.e(TAG, "> Situm: fetch Building info error: ${error?.message}")
                }
            })



        arView.load()
        // Now arView.sceneView is safe to use even if we change the behavior to instantiate it in
        // the load() call.
        arSceneHandler.setupSceneView(arView.sceneView)

        // Situm location and navigation listeners
        SitumSdk.locationManager().addLocationListener(arSceneHandler)


        isLoaded = true
        isLoading = false

        if (arSceneHandler.isDebugMode()) {
            handler.post(updateDebugInfoRunnable)
        }
    }

    fun unload() {
        Log.d(TAG, "Situm> AR> L&U> CALLED UNLOAD")
        if (isLoaded) {
            Log.d(TAG, "\tSitum> AR> L&U> ACTUALLY UNLOADED")
            SitumSdk.locationManager().removeLocationListener(arSceneHandler)

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
        arMethodCallSender.sendArGoneRequired()
    }

    fun updateDebugInfo() {
        arView.updateDebugInfo(arSceneHandler.getCurrentStatusLog())
    }

    override fun onARGoneRequired() {
        if (isLoaded) {
            unload()
            arMethodCallSender.sendArGoneRequired()
        }
    }
}