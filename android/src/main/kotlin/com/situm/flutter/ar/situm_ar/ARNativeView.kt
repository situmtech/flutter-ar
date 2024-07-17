package com.situm.flutter.ar.situm_ar

import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.TextView
import io.flutter.plugin.platform.PlatformView

internal class ARNativeView(context: Context, id: Int, creationParams: Map<String?, Any?>?) : PlatformView {
    private val arView: ARView

    override fun getView(): View {
        return arView
    }

    override fun dispose() {}

    init {
        arView = ARView(context)
    }
}