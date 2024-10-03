package com.situm.flutter.ar.situm_ar

import android.content.Context
import android.opengl.GLSurfaceView
import android.util.AttributeSet
import android.util.Log
import com.google.android.filament.Renderer
import com.google.android.filament.utils.Utils
import io.github.sceneview.ar.ARSceneView
import java.util.concurrent.Executors

class CustomARSceneView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : ForkSceneView(context, attrs, defStyleAttr) {

    fun resume() {
        arCore.resume(context, activity)
    }

    fun pause() {
        arCore.pause()
    }

    override fun destroy() {
        // TODO: review this method.
        try {
            super.destroy()
        } catch (e: Exception) {
            Log.e("ATAG", "Situm> AR> Destroy error captured: $e")
            if (!isDestroyed) {
                try {
                    // This call is causing NullPointerExceptions
                    cameraNode.destroy()
                } catch (e2: Exception) {
                    Log.e("ATAG", "Situm> AR> Destroy error captured: $e2")
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
//        try {
//            _cameraNode?.destroy()
//        }catch (e: Exception) {
//            Log.e("ATAG", "Situm> AR> Destroy error captured: $e")
//        }
    }
}
