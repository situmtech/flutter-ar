package com.situm.flutter.ar.situm_ar

import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel wrapper/adapter. Use this class to communicate with the Dart side.
 */
class ARMethodCallSender(
    private val methodChannel: MethodChannel
) {
    fun sendArGoneRequired() {
        methodChannel.invokeMethod("ArGoneRequired", mapOf("reason" to "lifecycle_stop" ))
    }
}