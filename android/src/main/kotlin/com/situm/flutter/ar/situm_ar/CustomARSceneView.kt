package com.situm.flutter.ar.situm_ar

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import io.github.sceneview.ar.ARSceneView
import java.util.concurrent.Executors

class CustomARSceneView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : ARSceneView(context, attrs, defStyleAttr) {

    fun resume() {
        arCore.resume(context, activity)
    }

    fun pause() {
        arCore.pause()
    }

    override fun destroy() {
        if (!isDestroyed) {
            try {
                // This call is causing NullPointerExceptions
                cameraNode.destroy()
            } catch (e: Exception) {
                Log.e("ATAG", "Destroy error captured: ${e.message}")
            }
            cameraStream?.destroy()
            lightEstimator?.destroy()
            planeRenderer.destroy()
            Executors.newSingleThreadExecutor().execute {
                // destroy() should be called off the main thread since it hangs for many seconds
                arCore.destroy()
            }
            isDestroyed = true
        }
        super.destroy()
    }
}
