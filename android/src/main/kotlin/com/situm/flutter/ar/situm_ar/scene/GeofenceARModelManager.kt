package com.situm.flutter.ar.situm_ar.scene

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.google.gson.JsonParser
import es.situm.sdk.location.GeofenceListener
import es.situm.sdk.model.cartography.Geofence
import io.github.sceneview.SceneView
import io.github.sceneview.node.ModelNode
import io.github.sceneview.node.Node
import io.github.sceneview.utils.getResourceUri
import kotlinx.coroutines.launch

class GeofenceARModelManager(
    private val context: Context,
    private val sceneView: SceneView,
    private val activity: Activity,
    private val fenceModels: MutableMap<String, SitumARModel>,
    private val onDebug: Boolean = false
) : GeofenceListener {

    private val handler = Handler(Looper.getMainLooper())
    private var proximityCheckRunnable: Runnable? = null

    init {
        start()
    }

    override fun onEnteredGeofences(geofences: MutableList<Geofence>?) {
        if (onDebug) {
            Toast.makeText(context, "Enter Geofence!", Toast.LENGTH_SHORT).show()
        }

        geofences?.forEach { geofence ->
            geofence.customFields.forEach { customField ->
                if (customField.key == "ar_metadata") {
                    try {
                        val extractedData = parseGeofenceArMetadata(customField)

                        extractedData.forEach { data ->
                            handleArMetadata(data, geofence.name)
                        }
                    } catch (e: Exception) {
                        Log.e(
                            ARSceneHandler.TAG,
                            "Error processing geofence metadata: ${e.message}",
                            e
                        )
                    }
                }
            }
        }
    }


    override fun onExitedGeofences(geofences: MutableList<Geofence>?) {
        if (onDebug) {
            Toast.makeText(context, "Exit Geofence!", Toast.LENGTH_SHORT).show()
        }
        geofences?.forEach { geofence ->
            geofence.customFields.forEach { customField ->
                if (customField.key == "ar_metadata") {
                    try {
                        val extractedData = parseGeofenceArMetadata(customField)
                        extractedData.forEach { data ->
                            val modelName = data["name"]
                            fenceModels[modelName]?.let { model ->
                                model.modelNode.isVisible = false
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(
                            ARSceneHandler.TAG,
                            "Error processing geofence metadata: ${e.message}",
                            e
                        )
                    }
                }
            }
        }
    }


    /**
     * Handles AR metadata for a specific geofence and attempts to load the corresponding model.
     */
    private fun handleArMetadata(data: Map<String, Any>, geofenceName: String) {
        val modelName = data["name"] as? String ?: return
        val scale = data["scale"] as? Float ?: return
        val coordinates = data["coordinates"] as? List<Float> ?: return
        val height = coordinates.getOrNull(2) ?: 0f

        Log.d(
            ARSceneHandler.TAG,
            "Nombre: $modelName, URL: ${data["url"]}, Escala: $scale, Coordenadas: $coordinates"
        )

        val existingModel = fenceModels[modelName]

        if (existingModel != null) {
            updateExistingModel(existingModel, height, sceneView.cameraNode)
        } else {
            val modelResId =
                activity.resources?.getIdentifier(modelName, "raw", activity.packageName)
            if (modelResId != null && modelResId != 0) {
                loadLocalModel(modelResId, modelName, scale, height, geofenceName)
            } else {
                loadRemoteModel(data["url"] as? String, modelName, scale, height, geofenceName)
            }
        }
    }


    /**
     * Updates an existing AR model with a new position and makes it visible.
     */
    private fun updateExistingModel(existingModel: SitumARModel, height: Float, cameraNode: Node) {
        val visiblePositions = getVisibleModelPositions(fenceModels)
        val newPosition = generateValidPosition(
            cameraPosition = cameraNode.worldPosition,
            cameraRotation = cameraNode.worldRotation,
            maxDistance = 5f,
            heightOffset = height,
            coneAngle = 30f,
            existingPositions = visiblePositions,
            minDistance = 2f
        )
        if (newPosition != null) {
            existingModel.modelNode.worldPosition = newPosition
            existingModel.modelNode.isVisible = true
        }

    }

    /**
     * Loads a local AR model resource and adds it to the scene.
     */
    private fun loadLocalModel(
        modelResId: Int,
        modelName: String,
        scale: Float,
        height: Float,
        geofenceName: String
    ) {
        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
            val modelNode = buildModelNode(modelResId, scale)
            modelNode?.let {
                addModelToScene(it, modelName, height, geofenceName)
            }
        }
    }

    private suspend fun buildModelNode(resId: Int, scale: Float): ModelNode? {
        return sceneView.modelLoader.loadModelInstance(activity.getResourceUri(resId))
            ?.let { modelInstance ->
                ModelNode(
                    modelInstance = modelInstance,
                    scaleToUnits = scale,
                ).apply {}

            }
    }

    private suspend fun fetchAndBuildModelNode(url: String, scale: Float): ModelNode? {
        return sceneView.modelLoader.loadModelInstance(url)
            ?.let { modelInstance ->
                ModelNode(
                    modelInstance = modelInstance,
                    scaleToUnits = scale,
                ).apply {}

            }
    }

    /**
     * Fetches and builds a remote AR model, then adds it to the scene.
     */
    private fun loadRemoteModel(
        modelUrl: String?,
        modelName: String,
        scale: Float,
        height: Float,
        geofenceName: String
    ) {
        if (modelUrl.isNullOrEmpty()) {
            Log.e(ARSceneHandler.TAG, "Invalid URL for model: $modelName")
            return
        }

        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
            try {
                val modelNode = fetchAndBuildModelNode(modelUrl, scale)
                modelNode?.let {
                    addModelToScene(it, modelName, height, geofenceName)
                }
            } catch (e: Exception) {
                Log.e(
                    ARSceneHandler.TAG,
                    "Error loading remote model: ${e.message}",
                    e
                )
            }
        }
    }

    /**
     * Adds a new AR model to the scene and updates the fenceModels map.
     */
    private fun addModelToScene(
        modelNode: ModelNode,
        modelName: String,
        height: Float,
        geofenceName: String
    ) {
        val situmARModel = SitumARModel(geofenceName, modelName, modelNode)
        fenceModels[modelName] = situmARModel

        val visiblePositions = getVisibleModelPositions(fenceModels)
        val newPosition = generateValidPosition(
            cameraPosition = sceneView.cameraNode.worldPosition,
            cameraRotation = sceneView.cameraNode.worldRotation,
            maxDistance = 5f,
            heightOffset = height,
            coneAngle = 30f,
            existingPositions = visiblePositions,
            minDistance = 2f
        )
        if (newPosition != null) {
            modelNode.worldPosition = newPosition
            modelNode.isVisible = true
            sceneView.addChildNode(modelNode)
        }
    }


    private fun parseGeofenceArMetadata(cf: Map.Entry<String, String>): List<Map<String, Any>> {
        val json = JsonParser.parseString(cf.value).asJsonObject
        val features = json["features"].asJsonArray

        // Iterar por cada "Feature" y extraer la información requerida
        val extractedData = features.map { feature ->
            val properties = feature.asJsonObject["properties"].asJsonObject
            val geometry = feature.asJsonObject["geometry"].asJsonObject

            // Crear un mapa con los datos que queremos extraer
            mapOf(
                "name" to properties["name"].asString,
                "url" to properties["url"].asString,
                "scale" to properties["scale"].asFloat,
                "coordinates" to geometry["coordinates"].asJsonArray.map { it.asFloat }
            )
        }
        return extractedData
    }


    private fun startModelProximityCheck() {
        proximityCheckRunnable = object : Runnable {
            override fun run() {
                val userPosition = sceneView.cameraNode.worldPosition
                val visiblePositions = getVisibleModelPositions(fenceModels)
                val hasNearbyModels = visiblePositions.any { position ->
                    distanceBetween(userPosition, position) < MIN_DISTANCE_TO_REGENERATE_MODELS
                }

                if (!hasNearbyModels) {
                    regenerateModelsNearUser()
                }

                handler.postDelayed(this, CHECK_MODELS_NEARBY_INTERVAL)
            }
        }
        proximityCheckRunnable?.let { handler.post(it) }
    }

    private fun stopModelProximityCheck() {
        proximityCheckRunnable?.let { handler.removeCallbacks(it) }
        proximityCheckRunnable = null
    }

    private fun regenerateModelsNearUser() {
        fenceModels.forEach { (_, model) ->
            if (model.modelNode.isVisible) {
                updateExistingModel(
                    model,
                    model.modelNode.worldPosition.y,
                    cameraNode = sceneView.cameraNode
                )
            }
        }
    }

    private fun start() {
        startModelProximityCheck()
    }

    fun stop() {
        stopModelProximityCheck()
    }

}
