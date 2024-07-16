package com.situm.flutter.ar.situm_ar

import android.os.Bundle
import android.view.View
import android.content.Context
import android.view.LayoutInflater
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.platform.PlatformViewsController
import io.flutter.plugin.common.StandardMessageCodec

class ARViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        return ARPlatformView(context)
    }
}

class ARPlatformView(context: Context?) : PlatformView {

    private val arView: ARView = LayoutInflater.from(context).inflate(R.layout.view_ar, null) as ARView

    override fun getView(): View {
        return arView
    }

    override fun dispose() {}
}
