package com.situm.flutter.ar.situm_ar

//
///** SitumArPlugin */
//class SitumArPlugin: FlutterPlugin, MethodCallHandler {
//  /// The MethodChannel that will the communication between Flutter and native Android
//  ///
//  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
//  /// when the Flutter Engine is detached from the Activity
//  private lateinit var channel : MethodChannel
//  //private lateinit var platformViewsController: PlatformViewsController
//
//  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
//    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "situm_ar")
//    channel.setMethodCallHandler(this)
//    //val lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(this)
//    flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("ARView", ARViewFactory())
//
//  }
//
//  override fun onMethodCall(call: MethodCall, result: Result) {
//    if (call.method == "getPlatformVersion") {
//      result.success("Android ${android.os.Build.VERSION.RELEASE}")
//    } else {
//      result.notImplemented()
//    }
//  }
//
//  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
//    channel.setMethodCallHandler(null)
//  }
//}
//

import android.app.Activity
import android.util.Log
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

object Constants {
    const val CHANNEL_ID = "SitumARView"
}

/** SceneviewFlutterPlugin */
class SitumArPlugin : FlutterPlugin, ActivityAware {

    private val TAG = "SceneviewFlutterPlugin"
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.i(TAG, "Situm> AR> onAttachedToEngine")
        this.flutterPluginBinding = flutterPluginBinding
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.i(TAG, "onDetachedFromEngine")
        this.flutterPluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.i(TAG, "onAttachedToActivity")
        val activity: Activity = binding.activity
        if (activity is LifecycleOwner) {
            Log.i(TAG, "activity is LifecycleOwner")
            flutterPluginBinding?.platformViewRegistry?.registerViewFactory(
                Constants.CHANNEL_ID,
                ARViewFactory(
                    binding.activity,
                    flutterPluginBinding!!.binaryMessenger,
                    activity.lifecycle,
                )
            )
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.i(TAG, "Situm> AR> onDetachedFromActivityForConfigChanges")
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.i(TAG, "Situm> AR> onReattachedToActivityForConfigChanges")
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        Log.i(TAG, "Situm> AR> onDetachedFromActivity")
    }
}
