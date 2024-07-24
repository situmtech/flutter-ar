package com.situm.flutter.ar.situm_ar

import androidx.annotation.NonNull
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformViewsController
import io.flutter.embedding.android.FlutterActivity

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
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding


/** SceneviewFlutterPlugin */
class SitumArPlugin : FlutterPlugin, ActivityAware,MethodCallHandler {

  private val TAG = "SceneviewFlutterPlugin"

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    Log.i(TAG, "onAttachedToEngine")
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "situm_ar")
    channel.setMethodCallHandler(this)
    this.flutterPluginBinding = flutterPluginBinding
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    Log.i(TAG, "onDetachedFromEngine")
    this.flutterPluginBinding = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    Log.i(TAG, "onAttachedToActivity")
    val activity: Activity = binding.activity
    if (activity is LifecycleOwner) {
      Log.i(TAG, "activity is LifecycleOwner")
      flutterPluginBinding?.platformViewRegistry?.registerViewFactory(
        "ARView",
        ARViewFactory(
          binding.activity,
          flutterPluginBinding!!.binaryMessenger,
          activity.lifecycle,
        )
      )
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }
  override fun onDetachedFromActivityForConfigChanges() {
    Log.i(TAG, "onDetachedFromActivityForConfigChanges")
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    Log.i(TAG, "onReattachedToActivityForConfigChanges")
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    Log.i(TAG, "onDetachedFromActivity")
  }
}
