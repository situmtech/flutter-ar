package com.situm.flutter.ar.situm_ar

import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * MethodCall wrapper/adapter. Use this class to handle Dart messages.
 */
class ARMethodCallHandler(
    private val controller: ARController
) {
    companion object {
        const val TAG = "Situm> AR>"
        const val DONE = "DONE"
    }

    fun handle(method: String?, arguments: Map<String, Any>, result: MethodChannel.Result) {
        when (method) {
            "load" -> handleLoad(arguments, result)
            "pause" -> handlePause(arguments, result)
            "resume" -> handleResume(arguments, result)
            "unload" -> handleUnload(arguments, result)
            else -> result.notImplemented()
        }
    }

    private fun handleLoad(arguments: Map<String, Any>, result: MethodChannel.Result) {
        controller.load()
        result.success(DONE)
        Log.d(TAG, "### AR has been LOADED and should be visible ###")
    }

    private fun handleUnload(arguments: Map<String, Any>, result: MethodChannel.Result) {
        controller.unload()
        result.success(DONE)
        Log.d(TAG, "### AR has been UNLOADED ###")
    }

    private fun handleResume(arguments: Map<String, Any>, result: MethodChannel.Result) {
        controller.resume()
        result.success(DONE)
        Log.d(TAG, "### AR has been RESUMED ###")
    }

    private fun handlePause(arguments: Map<String, Any>, result: MethodChannel.Result) {
        controller.pause()
        result.success(DONE)
        Log.d(TAG, "### AR has been PAUSED (camera should not be active) ###")
    }
}