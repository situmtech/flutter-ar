package com.situm.flutter.ar.situm_ar

import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.TextView
import io.flutter.plugin.platform.PlatformView
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.widget.FrameLayout
import androidx.core.view.isGone
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.google.ar.core.Anchor
import com.google.ar.core.Config
import com.google.ar.core.Plane
import com.google.ar.core.Pose
import com.google.ar.core.TrackingFailureReason
import dev.romainguy.kotlin.math.Quaternion
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.arcore.getUpdatedPlanes
import io.github.sceneview.ar.getDescription
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.node.Node

import io.github.sceneview.collision.Vector3
import io.github.sceneview.math.Position
import io.github.sceneview.node.ModelNode
import io.github.sceneview.utils.getResourceUri


import com.google.ar.sceneform.rendering.ViewRenderable
import io.github.sceneview.node.ViewNode
import io.github.sceneview.SceneView
import com.google.ar.sceneform.rendering.ViewAttachmentManager

import kotlinx.coroutines.launch
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

import android.app.Activity
import androidx.lifecycle.Lifecycle
//import com.google.ar.core.Config
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.github.sceneview.model.ModelInstance
import io.github.sceneview.node.RenderableNode

//internal class ARNativeView(context: Context, id: Int, creationParams: Map<String?, Any?>?) : PlatformView {
    class ARNativeView(
        private val context: Context,
        private val activity: Activity,
        lifecycle: Lifecycle,
        messenger: BinaryMessenger,
        id: Int,
    ) : PlatformView, MethodCallHandler {

    private val TAG = "ARNativeView"
    private val sceneView: ARSceneView
    private val _channel = MethodChannel(messenger, "ARView")

    // private val instructionText: TextView
    private var arrowNode: ModelNode? = null

    private var anchorNode: AnchorNode? = null
        set(value) {
            if (field != value) {
                field = value
                updateInstructions()
            }
        }
    private var trackingFailureReason: TrackingFailureReason? = null
        set(value) {
            if (field != value) {
                field = value
                updateInstructions()
            }
        }

         private var isLoading = false
        set(value) {
            field = value
            //loadingView.isGone = !value
        }


    override fun getView(): View {
        return sceneView
    }

    override fun dispose() {sceneView.destroy();}

    init {
        sceneView = ARSceneView(context,
            sharedLifecycle = lifecycle,
            sessionConfiguration = { session, config ->
            config.depthMode = if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                Config.DepthMode.AUTOMATIC
            } else {
                Config.DepthMode.DISABLED
            }
            config.instantPlacementMode = Config.InstantPlacementMode.DISABLED
            config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR},

        )


        setupSceneView();
        _channel.setMethodCallHandler(this)
    }



    private fun setupSceneView() {
        sceneView.apply {
            Log.d("ARView", "setp scene view")

            planeRenderer.isEnabled = true


            onSessionResumed = { session ->
                Log.i(TAG, "onSessionCreated")
            }
            onSessionFailed = { exception ->
                Log.e(TAG, "onSessionFailed : $exception")
            }
            onSessionCreated = { session ->
                Log.i(TAG, "onSessionCreated")
            }
            onTrackingFailureChanged = { reason ->
                Log.i(TAG, "onTrackingFailureChanged: $reason");
            }

            onSessionUpdated = { _, frame ->
                 if (anchorNode == null) {
                     frame.getUpdatedPlanes()
                         .firstOrNull { it.type == Plane.Type.HORIZONTAL_UPWARD_FACING }
                         ?.let { plane ->
                             addAnchorNode(plane.createAnchor(plane.centerPose))
                             // prueba nodo
                             //addAnchorTextNode(plane.createAnchor(plane.centerPose))
                            //
                         }
                 }
            }

            onTrackingFailureChanged = { reason ->
                //this@ARView.trackingFailureReason = reason
            }
            Log.d("ARView", "setp scene view 2")
            //  light {
            //     isEnabled = true
            //     intensity = 1.0f
            //     type = Light.Type.DIRECTIONAL
            // }

        }
        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
                Log.d("ARView", "buildAndAddArrowNode 3")

            if ((activity as LifecycleOwner).lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                // Actualiza el nodo en cada frame


                isLoading = true
                buildAndAddArrowNode()
                isLoading = false

                 sceneView.onFrame = {
                     arrowNode?.let { node ->
                         val distanceFromCamera = -0.5f
                         val forwardVector = Vector3(0.0f, 0.0f, 1.0f)
                         val cameraDirection = multiplyQuaternionVector(sceneView.cameraNode.quaternion, forwardVector)
                         val cameraLowerPosition = Vector3(sceneView.cameraNode.position.x, sceneView.cameraNode.position.y, sceneView.cameraNode.position.z)
                         val objectPosition = addVectors(cameraLowerPosition, multiplyVectorScalar(cameraDirection, distanceFromCamera))
                         node.transform(position = Position(x = objectPosition.x, y = objectPosition.y, z = objectPosition.z))
                         if (anchorNode != null) {
                             node.lookAt(targetNode = anchorNode!!, smooth = true, smoothSpeed = 1.0f)
                         }
                     }
                 }
            }
       }


    }


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {

    }

    private fun updateInstructions() {
        // instructionText.text = trackingFailureReason?.let {
        //     it.getDescription(context)
        // } ?: if (anchorNode == null) {
        //     context.getString(R.string.point_your_phone_down)
        // } else {
        //     null
        // }
    }

    private fun multiplyVectorScalar(vector: Vector3, scalar: Float): Vector3 {
        return Vector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }

    private fun multiplyQuaternionVector(quaternion: Quaternion, vector: Vector3): Vector3 {
        val x = quaternion.w * vector.x + quaternion.y * vector.z - quaternion.z * vector.y
        val y = quaternion.w * vector.y + quaternion.z * vector.x - quaternion.x * vector.z
        val z = quaternion.w * vector.z + quaternion.x * vector.y - quaternion.y * vector.x
        val w = -quaternion.x * vector.x - quaternion.y * vector.y - quaternion.z * vector.z
        return Vector3(
            x * quaternion.w + w * -quaternion.x + y * -quaternion.z - z * -quaternion.y,
            y * quaternion.w + w * -quaternion.y + z * -quaternion.x - x * -quaternion.z,
            z * quaternion.w + w * -quaternion.z + x * -quaternion.y - y * -quaternion.x
        )
    }

    private fun addVectors(vector1: Vector3, vector2: Vector3): Vector3 {
        return Vector3(vector1.x + vector2.x, vector1.y + vector2.y, vector1.z + vector2.z)
    }

    private fun addAnchorNode(anchor: Anchor) {
        val currentAnchor =  AnchorNode(sceneView.engine, anchor).apply {
                isEditable = true
                (activity as? LifecycleOwner)?.lifecycleScope?.launch {
                    isLoading = true
                    buildModelNode()?.let { addChildNode(it) }
                    isLoading = false
                }
        }
//        val textView = TextView(context).apply {
//            text = "Hola, AR!"
//            textSize = 100f//20f // Ajustar tamaño del texto
//            setTextColor(Color.RED)
//            setBackgroundColor(Color.BLACK) // Fondo transparente
//        }

        val transformableNode = Node(sceneView.engine)
        transformableNode.position = Position(0f, 0.2f, -0.2f)
        transformableNode.parent = currentAnchor
        transformableNode.isVisible = true

        val viewAttachmentManager = ViewAttachmentManager(context, sceneView)
        val textWrittenOverBadgeNode = ViewNode(sceneView.engine,sceneView.modelLoader,viewAttachmentManager);
        textWrittenOverBadgeNode.loadView(context,R.layout.text_poi_layout)
        textWrittenOverBadgeNode.isVisible = true

        textWrittenOverBadgeNode.worldPosition = Position(0f,0f,0f)
        //currentAnchor.addChildNode(textWrittenOverBadgeNode)
        sceneView.addChildNode(textWrittenOverBadgeNode)
//        ViewRenderable.builder().setView(context, R.layout.text_poi_layout)
//            .build(sceneView.engine)
//            .thenAccept {
//
//                Log.w("Situm>> ", "Creando ViewRenderable")
//                //textWrittenOverBadgeNode.setRenderable(it)
//                textWrittenOverBadgeNode.loadView(context,R.layout.text_poi_layout)
//                textWrittenOverBadgeNode.parent = transformableNode
//
//                //it.renderPriority = 0
//                currentAnchor.addChildNode(textWrittenOverBadgeNode)
//            }


        anchorNode = currentAnchor

        sceneView.addChildNode(
            currentAnchor
        )

        Log.w(TAG,textWrittenOverBadgeNode.parent)

     }

// private fun addAnchorTextNode(anchor: Anchor) {
//     // Crear un TextView con el texto que quieres mostrar
//     val textView = TextView(context).apply {
//         text = "Hola, AR!"
//         textSize = 2000f
//         setTextColor(Color.WHITE)
//         setBackgroundColor(Color.TRANSPARENT) // Fondo transparente
//     }
//     val viewAttachmentManager = ViewAttachmentManager(context, sceneView)
//     // Crear una instancia de ViewRenderable usando el TextView
//     ViewRenderable.builder()
//         .setView(context, textView)
//         .build(sceneView.engine)
//         .thenAccept { renderable ->
//             val viewNode = ViewNode(sceneView.engine, sceneView.modelLoader, viewAttachmentManager).apply {
//                 setRenderable(renderable)
//             }

//             // Crear un AnchorNode y añadir el ViewNode como hijo
//             val anchorNode = AnchorNode(sceneView.engine, anchor).apply {
//                 isEditable = true
//                 addChildNode(viewNode)
//             }

//             // Añadir el AnchorNode a la escena
//             sceneView.addChildNode(anchorNode)
//         }
//         .exceptionally { throwable ->
//             // Manejar errores al construir el renderable
//             Log.e("ViewNode", "Error al crear ViewRenderable", throwable)
//             null
//         }
// }

  private suspend fun buildModelNode(): ModelNode? {
        return sceneView.modelLoader.loadModelInstance(context.getResourceUri(R.raw.eren_hiphop_dance))?.let { modelInstance ->
            ModelNode(
                modelInstance = modelInstance,
                scaleToUnits = 0.5f,
                centerOrigin = Position(y = -0.5f)
            ).apply {
                isEditable = true
            }
        }
    }

    private suspend fun buildAndAddArrowNode() {
        Log.d("ARView", "buildAndAddArrowNode 1")

        val arrowModel = sceneView.modelLoader.loadModelInstance(context.getResourceUri(R.raw.arrow_rotated_center))
        val arrowPosition = Position(x = 0.0f, y = -1.0f, z = -6.0f)
        arrowModel?.let { modelInstance ->
            arrowNode = ModelNode(
                modelInstance = modelInstance,
                scaleToUnits = 0.1f,
                centerOrigin = arrowPosition
            ).apply {
                isEditable = true
                isPositionEditable = true
            }
            sceneView.addChildNode(arrowNode!!)
        }
    }
}