package com.situm.flutter.ar.situm_ar.scene

//import com.google.android.filament.Material

import android.app.Activity
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import android.widget.TextView
import android.widget.Toast
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.google.android.filament.Texture
import com.google.ar.sceneform.rendering.ViewAttachmentManager
import com.google.ar.sceneform.rendering.ViewRenderable
import com.situm.flutter.ar.situm_ar.CustomARSceneView
import com.situm.flutter.ar.situm_ar.R
import dev.romainguy.kotlin.math.Float3
import es.situm.sdk.SitumSdk
import es.situm.sdk.error.Error
import es.situm.sdk.location.ExternalArData
import es.situm.sdk.location.LocationListener
import es.situm.sdk.location.LocationStatus
import es.situm.sdk.model.cartography.BuildingInfo
import es.situm.sdk.model.cartography.Poi
import es.situm.sdk.model.cartography.PoiCategory
import es.situm.sdk.model.location.Location
import io.github.sceneview.collision.Vector3
import io.github.sceneview.geometries.Cylinder
import io.github.sceneview.geometries.Geometry
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.node.GeometryNode
import io.github.sceneview.node.ModelNode
import io.github.sceneview.node.Node
import io.github.sceneview.node.ViewNode
import io.github.sceneview.utils.getResourceUri
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL
import java.nio.ByteBuffer

const val DIRECTION_ARROW_TARGET_DISTANCE = 15f
const val RENDER_DISTANCE_FAR = 15f
const val CHECK_MODELS_NEARBY_INTERVAL = 10000L // 10 seconds
const val MIN_DISTANCE_TO_REGENERATE_MODELS = 10f // minimum distance meters

interface ARSceneHandlerCallback {
    fun onARGoneRequired()
}

class ARSceneHandler(
    private val activity: Activity,
    private val lifecycle: Lifecycle,
) : LocationListener {
    companion object {
        const val TAG = "Situm> AR>"
    }

    private var sendArGoneCallback: ARSceneHandlerCallback? = null
    private lateinit var sceneView: CustomARSceneView
    private val context: Context = activity
    private lateinit var viewAttachmentManager: ViewAttachmentManager

    private lateinit var geofenceARModelManager: GeofenceARModelManager

    private var arQuality: ARQuality = ARQuality()
    private var poiUtils: PoiUtils = PoiUtils()
    private lateinit var buildingInfo: BuildingInfo
    private lateinit var currentPosition: Location

    private var onDebug: Boolean = true

    private var isRedrawing: Boolean = false        // not allow to redraw if is already redrawing
    private var lastTimestampRedraw: Long = 0

    private val dashboardDomain: String = "https://dashboard.situm.com"

    private var arrowNode: ModelNode? = null
    private var diskGeometry: Geometry? = null

    private lateinit var pois: List<Poi>
    private val poisAR = mutableMapOf<String, PoiAR>()
    private val fenceModels = mutableMapOf<String, SitumARModel>()
    private val poisTexturesMap = mutableMapOf<String, Texture?>()


    private lateinit var routeARManager: RouteARManager

    fun setARGoneCallback(callback: ARSceneHandlerCallback) {
        this.sendArGoneCallback = callback
//        this.routeARManager.setARGoneCallback(callback)
    }


    private fun setPois(pois: List<Poi>) {
        this.pois = pois
    }

    private fun updatePoisAR() {
        for (poi in pois) {
            poisAR[poi.identifier] = PoiAR(poi)
        }
    }

    private fun loadPoiImages() {
        CoroutineScope(Dispatchers.Main).launch {
            for (poi in pois) {

                Log.d(
                    TAG,
                    "> Situm: To download texture from : ${dashboardDomain + poi.category.unselectedIconUrl.value}"
                )
                if (!poisTexturesMap.containsKey(poi.category.identifier)) {
                    val texture = loadTextureFromUrlAsync(
                        dashboardDomain + poi.category.unselectedIconUrl.value
                    )
                    if (texture != null) {
                        poisTexturesMap[poi.category.identifier] = texture
                    }
                }
            }
        }
    }

    private fun setCurrentLocation(location: Location) {
        // if floor change, redraw
        if (::currentPosition.isInitialized && this.currentPosition.floorIdentifier != location.floorIdentifier) {
            worldRedraw()
        }
        this.currentPosition = location
        routeARManager.currentPosition = location
    }

    fun setBuildingInfo(buildingInfo: BuildingInfo) {
        Log.d(TAG, "set building info : $buildingInfo")
        this.buildingInfo = buildingInfo
        setPois(buildingInfo.indoorPOIs as List<Poi>)
        updatePoisAR()
        loadPoiImages()
    }


    fun setupSceneView(sceneView: CustomARSceneView) {
        viewAttachmentManager = ViewAttachmentManager(context, sceneView)
        viewAttachmentManager.onResume()


        this.sceneView = sceneView
        Log.d(TAG, ">>>Setup ARSceneView 1 ")
        sceneView.apply {

            Log.d(TAG, ">>>Setup ARSceneView")
            planeRenderer.isEnabled = false

            onSessionResumed = { session ->
                Log.i(TAG, ">>>onSessionCreated")
            }
            onSessionFailed = { exception ->
                Log.e(TAG, ">>>onSessionFailed : $exception")
            }
            onSessionCreated = { session ->
                Log.i(TAG, ">>>onSessionCreated")
            }
            onTrackingFailureChanged = { reason ->
                Log.i(TAG, ">>>onTrackingFailureChanged: $reason")
            }
            onSessionUpdated = { _, frame ->
            }

            sceneView.cameraNode.far = RENDER_DISTANCE_FAR
        }

        routeARManager = RouteARManager(context,sceneView)
        this.sendArGoneCallback?.let { routeARManager.setARGoneCallback(it) }
        
        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
            if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                diskGeometry =
                    Cylinder.Builder().radius(0.5f).height(0.01f).build(sceneView.engine)
                // Actualiza el nodo en cada frame
                buildAndAddArrowNode()
                sceneView.onFrame = {
                    arrowNode?.let { node ->
                        val distanceFromCamera = -0.5f
                        val forwardVector = Vector3(0.0f, 0.0f, 1.0f)
                        val cameraDirection =
                            io.github.sceneview.collision.Quaternion.rotateVector(
                                io.github.sceneview.collision.Quaternion(
                                    sceneView.cameraNode.quaternion.x,
                                    sceneView.cameraNode.quaternion.y,
                                    sceneView.cameraNode.quaternion.z,
                                    sceneView.cameraNode.quaternion.w
                                ), forwardVector
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
                                x = objectPosition.x, y = objectPosition.y, z = objectPosition.z
                            )
                        )
                        if (routeARManager.targetArrow != null) {
                            node.lookAt(
                                targetWorldPosition = routeARManager.targetArrow!!,
                                smooth = true,
                                smoothSpeed = 1.0f
                            )
                        }
                    }

                    for (poi in poisAR.values) {     // force to look at camera. Maybe node and view node should be children form same node
                        poi.node?.lookAt(sceneView.cameraNode)
                        poi.node?.scale = Float3(-1f, 1f, 1f)
                    }
                    updateVisualOdometry()
                }
            }
        }
        geofenceARModelManager =
            GeofenceARModelManager(context, sceneView, activity, fenceModels, onDebug)
        SitumSdk.locationManager().setGeofenceListener(geofenceARModelManager)
        SitumSdk.navigationManager().addNavigationListener(routeARManager)

    }




    private suspend fun addPoisToScene(pois: List<Poi>, arcorePositions: List<Vector3>) {
        //clearPoiNodes()
        logExecutionTime(" >> make poi nodes invisible  ") {
            makePoiNodesInvisible()
        }

        for (i in pois.indices) {

            val arcorePosition = arcorePositions[i]
            val position = Position(arcorePosition.x, arcorePosition.y, arcorePosition.z)
            poisAR[pois[i].identifier]?.let {
                addBaseNode(it, position)
            }

            logExecutionTime(" >> load textview  ") {
                withContext(Dispatchers.Main) {
                    poisAR[pois[i].identifier]?.let {
                        loadTextViewInAR(
                            it,
                            poisAR[pois[i].identifier]!!.poi.name
                        )
                    }
                }
            }

            logExecutionTime(" >>draw disc  ") {
                poisAR[pois[i].identifier]?.poi?.let {
                    drawDiskWithImage(
                        poisAR[pois[i].identifier]!!,
                        Position(0f, -0.5f, 0f),
                        it.category
                    )
                }
            }
        }
    }

    private fun addBaseNode(poiAR: PoiAR, position: Position) {
        if (poiAR.node != null) {
            poiAR.node?.worldPosition = position
            poiAR.node?.lookAt(sceneView.cameraNode)
            poiAR.node?.isVisible = true
            return
        } else {
            val node = Node(sceneView.engine)
            node.worldPosition = position
            node.lookAt(sceneView.cameraNode)
            poiAR.node = node

            sceneView.addChildNode(node)
        }

    }

    private fun loadTextViewInAR(poiAR: PoiAR, textString: String) {
        if (poiAR.viewNode != null) {
            poiAR.viewNode!!.isVisible = true
            return
        }

        val textView = TextView(context).apply {
            text = textString
            setTextAppearance(R.style.CustomTextWithShadow) // Aplica el estilo
            setPadding(10, 10, 10, 10) // Ajuste opcional
        }

        ViewRenderable.builder().setView(context, textView).build(sceneView.engine)
            .thenAccept { viewRenderable ->
                val viewNode =
                    ViewNode(sceneView.engine, sceneView.modelLoader, viewAttachmentManager)
                viewNode.setRenderable(viewRenderable)
                poiAR.viewNode = viewNode

                poiAR.node?.addChildNode(viewNode)
            }.exceptionally { throwable ->
                throwable.printStackTrace()
                null
            }
    }

    private suspend fun loadTextureFromUrlAsync(imageUrl: String): Texture? {
        return withContext(Dispatchers.IO) {
            try {
                val bitmap = BitmapFactory.decodeStream(URL(imageUrl).openStream())
                // Pasar los datos del Bitmap a Filament
                val buffer = ByteBuffer.allocate(bitmap.byteCount)
                bitmap.copyPixelsToBuffer(buffer)
                buffer.rewind()

                // Asignar el contenido del buffer a la textura de Filament
                Texture.Builder().width(bitmap.width).height(bitmap.height).build(sceneView.engine)
                    .apply {
                        setImage(
                            sceneView.engine, 0, Texture.PixelBufferDescriptor(
                                buffer, Texture.Format.RGBA, Texture.Type.UBYTE
                            )
                        )
                    }
            } catch (e: Exception) {
                Log.e(TAG, ">> Exceptiom loading texture : $e")
                e.printStackTrace()
                null
            }
        }
    }

    private fun drawDiskWithImage(poiAR: PoiAR, arPosition: Position, poiCategory: PoiCategory) {

        if (poiAR.node != null && poiAR.geometryNode != null) {
            poiAR.node?.isVisible = true
            return
        }

        val texture = poisTexturesMap[poiCategory.identifier]
        if (texture != null && diskGeometry != null) {
            val materialInstance =
                MaterialLoader(sceneView.engine, context).createTextureInstance(
                    texture,
                    true,
                    0.0f,
                    0.1f,
                    0.5f
                )
            val diskNode = GeometryNode(sceneView.engine, diskGeometry!!, materialInstance)

            diskNode.rotation = Rotation(-90f, 0f, 0f)
            diskNode.position = arPosition
            if (poiAR.node != null) {
                poiAR.node!!.addChildNode(diskNode)
                poiAR.geometryNode = diskNode
            }
        } else {
            Log.e(TAG, ">> Failed to load texture.")
        }
    }

    private suspend fun loadPois() {
        if (::currentPosition.isInitialized && ::pois.isInitialized && pois.isNotEmpty()) {
            val nearPois = poiUtils.filterPoisByDistanceAndFloor(pois, currentPosition, 50)
            val arcorePositions = generateARCorePositions(
                nearPois, currentPosition,sceneView.cameraNode
            ) { poi -> poi.position.cartesianCoordinate }
            logExecutionTime(" >> add pois to scene ") {
                addPoisToScene(nearPois, arcorePositions)
            }
        }
    }

    private suspend fun buildAndAddArrowNode() {
        Log.d(TAG, "buildAndAddArrowNode 1")
        val arrowModel =
            sceneView.modelLoader.loadModelInstance(activity.getResourceUri(R.raw.arrow_situm_rotated))
        //sceneView.modelLoader.loadModelInstance(activity.getResourceUri(R.raw.arrow_rotated_center))
        val arrowPosition = Position(x = 0.0f, y = -1.0f, z = -6.0f)
        arrowModel?.let { modelInstance ->
            arrowNode = ModelNode(
                modelInstance = modelInstance, scaleToUnits = 0.1f, centerOrigin = arrowPosition
            ).apply {
                isEditable = true
                isPositionEditable = true
            }
            routeARManager.arrowNode = arrowNode
            sceneView.addChildNode(arrowNode!!)
        }
    }

    fun unload() {
        viewAttachmentManager.onPause()
        arrowNode?.let { sceneView.removeChildNode(it) }
        arrowNode = null
        clearPoiNodes()
        clearModels()
        pois = emptyList()
        poisTexturesMap.clear()
        sceneView.clearChildNodes()
        diskGeometry?.let { diskGeometry = null }
        geofenceARModelManager.stop()
        routeARManager.stop()
        SitumSdk.navigationManager().removeNavigationListener(routeARManager)
    }


    private fun clearAllNodes(node: Node) {
        node.childNodes.forEach { clearAllNodes(it) }  // Limpia recursivamente
        node.parent?.removeChildNode(node)           // Elimina el nodo del padre
        node.destroy()

    }

    private fun makePoiNodesInvisible() {
        for (poi in poisAR.values) {
            poi.node?.isVisible = false
            //poi.viewNode.isVisible = false TODO: Esto no funciona. Se estan eliminando los textos de cada vez
            poi.viewNode?.let { poi.node?.removeChildNode(it) }
            poi.viewNode = null
        }
    }

    private fun clearPoiNodes() {
        for (poi in poisAR.values) {
            poi.node?.let { sceneView.removeChildNode(it) }
            poi.clear()
        }
        poisAR.clear()
    }

    private fun clearModels() {
        for (fenceModel in fenceModels) {

            fenceModel.value.removeFromScene(sceneView)
        }
        fenceModels.clear()
    }

    // Location Listener
    override fun onLocationChanged(location: Location) {
        logExecutionTime(" >> on location changed  ") {
            this.setCurrentLocation(location)
            arQuality.updateSitumLocation(location)
            arQuality.updateARLocation(
                sceneView.cameraNode.worldPosition,
                sceneView.cameraNode.worldRotation
            )
            if (arQuality.hasToResetWorld()) {
                Log.e(TAG, ">> Situm : has to reset!")
                val timestampRedraw = System.currentTimeMillis()
                if (timestampRedraw - lastTimestampRedraw > 5000) {
                    if (onDebug) {
                        Toast.makeText(context, "Refresh!", Toast.LENGTH_SHORT).show()
                    }
                    worldRedraw()
                    lastTimestampRedraw = timestampRedraw
                }

            } else {
                Log.e(TAG, ">> Situm : NOT reset!")
            }
        }
    }

    override fun onStatusChanged(p0: LocationStatus) {

    }

    override fun onError(p0: Error) {

    }

    // callable from dart
    fun worldRedraw() {
        if (isRedrawing) {
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            isRedrawing = true
            logExecutionTime(" >> Load pois") {
                loadPois()
            }
            logExecutionTime(" >> update route nodes ") {
                routeARManager.updateRouteNodes()
            }
            logExecutionTime(" >> update target arrow  ") {
                routeARManager.updateTargetArrowOnARRoute(DIRECTION_ARROW_TARGET_DISTANCE)
            }
            isRedrawing = false
        }
    }

    fun updateArrowTarget(){
        routeARManager.updateArrowTarget()
    }


    fun getCurrentStatusLog(): String {
        return arQuality.getCurrentStatusLog()
    }

    private fun getVisualOdometry(): String {
        val timestamp = System.currentTimeMillis()

        return """
            {"message":{
                "position": {
                    "x": ${this.sceneView.cameraNode.worldPosition.x},
                    "y": ${this.sceneView.cameraNode.worldPosition.y},
                    "z": ${-this.sceneView.cameraNode.worldPosition.z}
                },
                "eulerRotation": {
                    "x": ${this.sceneView.cameraNode.worldRotation.x},
                    "y": ${this.sceneView.cameraNode.worldRotation.y},
                    "z": ${this.sceneView.cameraNode.worldRotation.z}
                },
                "timestamp": $timestamp
             }
            }
        """.trimIndent()
    }

    private fun updateVisualOdometry() {
        val externalAR = ExternalArData.Builder().rawJsonString(getVisualOdometry()).build()
        SitumSdk.locationManager().addExternalArData(externalAR)
    }

    fun switchShowRouteOnAR() {
       routeARManager.switchShowRouteOnAR()
    }

    fun isDebugMode(): Boolean {
        return onDebug
    }

    fun setDebugMode(debug: Boolean) {
        onDebug = debug
    }
}