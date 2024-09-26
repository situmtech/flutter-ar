package com.situm.flutter.ar.situm_ar.scene

import android.app.Activity
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.google.ar.core.Anchor
import com.google.ar.core.Plane
import com.situm.flutter.ar.situm_ar.CustomARSceneView
import com.situm.flutter.ar.situm_ar.R
import dev.romainguy.kotlin.math.Quaternion
import io.github.sceneview.ar.arcore.getUpdatedPlanes
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.collision.Vector3
import io.github.sceneview.math.Position
import io.github.sceneview.node.ModelNode
import io.github.sceneview.utils.getResourceUri
import kotlinx.coroutines.launch

class ARSceneHandler(
    private val activity: Activity,
    private val lifecycle: Lifecycle,
) {
    companion object {
        const val TAG = "Situm> AR>"
    }

    private var arrowNode: ModelNode? = null
    private var anchorNode: AnchorNode? = null
    private lateinit var sceneView: CustomARSceneView

    fun setupSceneView(sceneView: CustomARSceneView) {
        this.sceneView = sceneView
        sceneView.apply {
            Log.d(TAG, "Setup ARSceneView")
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
                        }
                }
            }
            onTrackingFailureChanged = { reason ->
                //this@ARView.trackingFailureReason = reason
            }
            Log.d("ARView", "setp scene view 2")

        }
        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
            Log.d("ARView", "buildAndAddArrowNode 3")

            if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                // Actualiza el nodo en cada frame
                buildAndAddArrowNode()
                sceneView.onFrame = {
                    arrowNode?.let { node ->
                        val distanceFromCamera = -0.5f
                        val forwardVector = Vector3(0.0f, 0.0f, 1.0f)
                        val cameraDirection =
                            multiplyQuaternionVector(
                                sceneView.cameraNode.quaternion,
                                forwardVector
                            )
                        val cameraLowerPosition = Vector3(
                            sceneView.cameraNode.position.x,
                            sceneView.cameraNode.position.y,
                            sceneView.cameraNode.position.z
                        )
                        val objectPosition = addVectors(
                            cameraLowerPosition,
                            multiplyVectorScalar(cameraDirection, distanceFromCamera)
                        )
                        node.transform(
                            position = Position(
                                x = objectPosition.x,
                                y = objectPosition.y,
                                z = objectPosition.z
                            )
                        )
                        if (anchorNode != null) {
                            node.lookAt(
                                targetNode = anchorNode!!,
                                smooth = true,
                                smoothSpeed = 1.0f
                            )
                        }
                    }
                }
            }
        }
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
        sceneView.addChildNode(
            AnchorNode(sceneView.engine, anchor).apply {
                isEditable = true
                (activity as? LifecycleOwner)?.lifecycleScope?.launch {
                    buildModelNode()?.let { addChildNode(it) }
                }
                anchorNode = this
            }
        )
    }

    private suspend fun buildModelNode(): ModelNode? {
        return sceneView.modelLoader.loadModelInstance(activity.getResourceUri(R.raw.eren_hiphop_dance))
            ?.let { modelInstance ->
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
        Log.d(TAG, "buildAndAddArrowNode 1")
        val arrowModel =
            sceneView.modelLoader.loadModelInstance(activity.getResourceUri(R.raw.arrow_rotated_center))
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