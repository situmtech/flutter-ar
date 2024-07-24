package com.situm.flutter.ar.situm_ar

import android.os.Bundle
import android.view.View
import android.content.Context
import android.view.LayoutInflater
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.platform.PlatformViewsController
import io.flutter.plugin.common.StandardMessageCodec

//class ARViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
//    override fun create(context: Context, id: Int, args: Any?): PlatformView {
//        val creationParams = args as Map<String?, Any?>?
//
//        return ARNativeView(context, id, creationParams)
//    }
//}


import android.app.Activity
import android.util.Log
import androidx.lifecycle.Lifecycle
import io.flutter.plugin.common.BinaryMessenger

class ARViewFactory(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
    private val lifecycle: Lifecycle,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        Log.d("Factory", "Creating new view instance")
        return ARNativeView(context, activity, lifecycle, messenger, viewId);
    }
}