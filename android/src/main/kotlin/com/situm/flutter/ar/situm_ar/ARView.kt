package com.situm.flutter.ar.situm_ar

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
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
import io.github.sceneview.collision.Vector3
import io.github.sceneview.math.Position
import io.github.sceneview.node.ModelNode
import io.github.sceneview.utils.getResourceUri
import kotlinx.coroutines.launch

class ARView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val sceneView: ARSceneView
    private val loadingView: View
    private val instructionText: TextView
    private var arrowNode: ModelNode? = null

    private var isLoading = false
        set(value) {
            field = value
            loadingView.isGone = !value
        }

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

    init {
        LayoutInflater.from(context).inflate(R.layout.view_ar, this, true)

        sceneView = findViewById(R.id.sceneView)
        instructionText = findViewById(R.id.instructionText)
        loadingView = findViewById(R.id.loadingView)

        setupSceneView()
    }

    private fun setupSceneView() {
        (context as? LifecycleOwner)?.lifecycle?.let { lifecycle ->
            sceneView.lifecycle = lifecycle
        }

        sceneView.apply {
            planeRenderer.isEnabled = true
            configureSession { session, config ->
                config.depthMode = when (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    true -> Config.DepthMode.AUTOMATIC
                    else -> Config.DepthMode.DISABLED
                }
                config.instantPlacementMode = Config.InstantPlacementMode.DISABLED
                config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
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
                this@ARView.trackingFailureReason = reason
            }
        }

        (context as? LifecycleOwner)?.lifecycleScope?.launch {
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

    private fun updateInstructions() {
        instructionText.text = trackingFailureReason?.let {
            it.getDescription(context)
        } ?: if (anchorNode == null) {
            context.getString(R.string.point_your_phone_down)
        } else {
            null
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
                (context as? LifecycleOwner)?.lifecycleScope?.launch {
                    isLoading = true
                    buildModelNode()?.let { addChildNode(it) }
                    isLoading = false
                }
                anchorNode = this
            }
        )
    }

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
