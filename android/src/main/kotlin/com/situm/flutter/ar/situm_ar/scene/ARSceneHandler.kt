package com.situm.flutter.ar.situm_ar.scene

//import com.google.android.filament.Material

import android.app.Activity
import android.content.Context
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.TextView
import android.widget.Toast
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.google.android.filament.Texture
import com.google.ar.sceneform.rendering.ViewAttachmentManager
import com.google.ar.sceneform.rendering.ViewRenderable
import com.google.gson.JsonParser
import com.situm.flutter.ar.situm_ar.CustomARSceneView
import com.situm.flutter.ar.situm_ar.R
import dev.romainguy.kotlin.math.Float3
import es.situm.sdk.SitumSdk
import es.situm.sdk.error.Error
import es.situm.sdk.location.ExternalArData
import es.situm.sdk.location.GeofenceListener
import es.situm.sdk.location.LocationListener
import es.situm.sdk.location.LocationStatus
import es.situm.sdk.model.cartography.BuildingInfo
import es.situm.sdk.model.cartography.Geofence
import es.situm.sdk.model.cartography.Poi
import es.situm.sdk.model.cartography.PoiCategory
import es.situm.sdk.model.directions.Route
import es.situm.sdk.model.directions.RouteSegment
import es.situm.sdk.model.location.CartesianCoordinate
import es.situm.sdk.model.location.Location
import es.situm.sdk.model.navigation.NavigationProgress
import es.situm.sdk.navigation.NavigationListener
import io.github.sceneview.collision.Vector3
import io.github.sceneview.geometries.Cylinder
import io.github.sceneview.geometries.Geometry
import io.github.sceneview.geometries.Sphere
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.math.Color
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

interface ARSceneHandlerCallback {
    fun onARGoneRequired()
}

class ARSceneHandler(
    private val activity: Activity,
    private val lifecycle: Lifecycle,
) : NavigationListener, LocationListener, GeofenceListener {
    companion object {
        const val TAG = "Situm> AR>"
    }

    private var sendArGoneCallback: ARSceneHandlerCallback? = null
    private lateinit var sceneView: CustomARSceneView
    private val context: Context = activity
    private lateinit var viewAttachmentManager: ViewAttachmentManager

    private var arQuality: ARQuality = ARQuality()
    private var poiUtils: PoiUtils = PoiUtils()
    private lateinit var buildingInfo: BuildingInfo
    private lateinit var currentPosition: Location

    private var onDebug: Boolean = true
    private var hasToShowDebugRoute: Boolean = false
    private var isRedrawing: Boolean = false        // not allow to redraw if is already redrawing
    private var lastTimestampRedraw: Long = 0

    private val dashboardDomain: String = "https://dashboard.situm.com"

    private var arrowNode: ModelNode? = null
    private var targetArrow: Position? = null
    private var diskGeometry: Geometry? = null

    private lateinit var pois: List<Poi>
    val poisAR = mutableMapOf<String, PoiAR>()
    val fenceModels = mutableMapOf<String, SitumARModel>()
    val poisTexturesMap = mutableMapOf<String, Texture?>()

    private val checkInterval = 10000L // 10 segundos
    private val minDistanceThresholdToRegenerateModels = 10f // Distancia mínima en metros
    private val handler = Handler(Looper.getMainLooper())
    private var proximityCheckRunnable: Runnable? = null

    private lateinit var currentSegment: RouteSegment
    private var routePointsAR: MutableList<Vector3> = mutableListOf()
    private lateinit var route: Route

    private val routeNodes: MutableList<Node> = mutableListOf()     // only for debug

    fun setCallback(callback: ARSceneHandlerCallback) {
        this.sendArGoneCallback = callback
    }

    fun setRoute(route: Route) {
        this.route = route
    }

    private fun setCurrentSegment(routeSegment: RouteSegment) {
        this.currentSegment = routeSegment
    }

    fun setPois(pois: List<Poi>) {
        this.pois = pois
    }

    fun updatePoisAR() {
        for (poi in pois) {
            poisAR.set(poi.identifier, PoiAR(poi))
        }
    }

    fun loadPoiImages() {
        CoroutineScope(Dispatchers.Main).launch {
            for (poi in pois) {

                Log.d(
                    TAG,
                    "> Situm: To download texture from : ${dashboardDomain + poi.category.unselectedIconUrl.value.toString()}"
                )
                if (!poisTexturesMap.containsKey(poi.category.identifier)) {
                    val texture = loadTextureFromUrlAsync(
                        context, dashboardDomain + poi.category.unselectedIconUrl.value.toString()
                    )
                    if (texture != null) {
                        poisTexturesMap[poi.category.identifier] = texture
                    }
                }
            }
        }
    }

    fun setCurrentLocation(location: Location) {
        // if floor change, redraw
        if (::currentPosition.isInitialized && this.currentPosition.floorIdentifier != location.floorIdentifier) {
            worldRedraw()
        }
        this.currentPosition = location
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
                        if (targetArrow != null) {
                            node.lookAt(
                                targetWorldPosition = targetArrow!!,
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
        startModelProximityCheck()
    }


    private fun <T> generateARCorePositions(
        items: List<T>, currentLocation: Location, getCoordinate: (T) -> CartesianCoordinate
    ): List<Vector3> {

        val arCorePositions = mutableListOf<Vector3>()
        val cameraPosition = sceneView.cameraNode.worldPosition
        val cameraBearing = sceneView.cameraNode.worldRotation.y

        // Keep only horizontal rotation
        val cameraHorizontalRotation = io.github.sceneview.collision.Quaternion.axisAngle(
            Vector3(0.0f, 1.0f, 0.0f), cameraBearing
        )

        // Situm rotation
        val situmBearing =
            currentLocation.cartesianBearing?.degreesClockwise()?.plus(90) ?: return emptyList()
        val situmBearingMinusRotation = io.github.sceneview.collision.Quaternion.axisAngle(
            Vector3(0f, -1f, 0f), situmBearing.toFloat()
        )

        for (item in items) {
            val coordinate = getCoordinate(item)
            val xA = coordinate.x
            val yA = coordinate.y

            // Calculate relative position
            val relativeItemPosition = Vector3(
                (xA - currentLocation.cartesianCoordinate.x).toFloat(),
                0f,
                (yA - currentLocation.cartesianCoordinate.y).toFloat()
            )

            // Apply rotations
            val positionMinusSitumRotated = io.github.sceneview.collision.Quaternion.rotateVector(
                situmBearingMinusRotation, relativeItemPosition
            )

            val positionRotatedAndTranslatedToCamera =
                io.github.sceneview.collision.Quaternion.rotateVector(
                    cameraHorizontalRotation, positionMinusSitumRotated
                ).apply {
                    x = cameraPosition.x + this.x
                    y = cameraPosition.y
                    z = cameraPosition.z - this.z
                }

            Log.d(
                TAG,
                "> Situm: generateARCorePositions> item.position: $xA , $yA / relativeItemPosition: ${relativeItemPosition.x} , ${relativeItemPosition.z}" + " bearingAdjustedPosition: ${positionMinusSitumRotated.x} , ${positionMinusSitumRotated.z}" + " transformedPosition: ${positionRotatedAndTranslatedToCamera.x} , ${positionRotatedAndTranslatedToCamera.z}"
            )

            arCorePositions.add(positionRotatedAndTranslatedToCamera)
        }

        return arCorePositions
    }

    private suspend fun addPoisToScene(pois: List<Poi>, arcorePositions: List<Vector3>) {
        //clearPoiNodes()
        logExecutionTime(" >> make poi nodes invisible  ") {
            makePoiNodesInvisible()
        }

        for (i in pois.indices) {

            val arcorePosition = arcorePositions[i]
            val position = Position(arcorePosition.x, arcorePosition.y, arcorePosition.z)
            poisAR.get(pois[i].identifier)?.let {
                addBaseNode(it, position)
            }

            logExecutionTime(" >> load textview  ") {
                withContext(Dispatchers.Main) {
                    poisAR.get(pois[i].identifier)?.let {
                        loadTextViewInAR(
                            it,
                            poisAR.get(pois[i].identifier)!!.poi.name
                        )
                    }
                }
            }
            val positionDisk = Position(arcorePosition.x, arcorePosition.y - 0.5f, arcorePosition.z)
            logExecutionTime(" >>draw disc  ") {
                poisAR.get(pois[i].identifier)?.poi?.let {
                    drawDiskWithImage(
                        poisAR.get(pois[i].identifier)!!,
                        positionDisk,
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
            var node = Node(sceneView.engine)
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

    private fun updateRouteNodes() {
        if (!this::currentSegment.isInitialized || !this::currentPosition.isInitialized) {
            return
        }
        currentSegment.points.let { nonNullRoute ->
            val arCorePositionsForPoints = generateARCorePositions(
                nonNullRoute, currentPosition
            ) { point -> point.cartesianCoordinate }

            routePointsAR = interpolatePositions(arCorePositionsForPoints, 1.0f)
            if (hasToShowDebugRoute) {
                addSpheresToScene(routePointsAR)
            }
        }
    }

    private fun initSpheresRoute(numSpheres: Int, sphereRadius: Float = 0.1f) {
        val material =
            MaterialLoader(sceneView.engine, context).createColorInstance(Color(0f, 0f, 1f, 0.5f))
        val sphereGeometry =
            Sphere.Builder().radius(sphereRadius).center(Position(0f, 0f, 0f))
                .build(sceneView.engine)
        for (i in 0 until numSpheres) {
            routeNodes.add(
                GeometryNode(
                    sceneView.engine,
                    sphereGeometry,
                    material
                ).apply { isVisible = false })
        }
    }

    private fun makeRouteInvisible() {
        for (node in routeNodes) {
            node.isVisible = false
        }
        sceneView.addChildNodes(routeNodes)
    }

    private fun addSpheresToScene(positions: List<Vector3>) {

        if (routeNodes.isEmpty()) {
            initSpheresRoute(20)
        }
        makeRouteInvisible()
        val maxIndex = minOf(positions.size, routeNodes.size)

        for (i in 0 until maxIndex) {
            routeNodes.get(i).apply {
                worldPosition = Position(positions.get(i).x, positions.get(i).y, positions.get(i).z)
                isVisible = true
            }
        }
    }

    // from current AR position and AR RouteNodes, projects position on route and finds next node at n distance (?)
    private fun updateTargetArrowOnARRoute(minDistanceMeters: Float) {
        val cameraPosition = sceneView.cameraNode.worldPosition
        var closestPoint: Vector3? = null
        var targetPoint: Vector3? = null
        var minDistanceToCamera = Float.MAX_VALUE

        Log.d(TAG, ">> updateTargetArrowOnARRoute  ")
        //  Find closest node
        for (point in routePointsAR) {
            Log.d(TAG, "> route point: ${point} ")
            val distanceToCamera = calculate2DDistance(
                Vector3(cameraPosition.x, cameraPosition.y, cameraPosition.z),
                point
            )

            if (distanceToCamera < minDistanceToCamera) {
                minDistanceToCamera = distanceToCamera
                closestPoint = point
            }
        }
        if (closestPoint == null) {
            Log.w(TAG, "> No closest node found.")
            return
        } else {
            Log.w(TAG, "< Closest node: ${closestPoint}")
        }

        for (i in routePointsAR.indexOf(closestPoint) until routePointsAR.size) {
            val position = routePointsAR[i]
            val distanceFromClosest = calculate2DDistance(closestPoint, position)
            Log.d(
                TAG,
                ">> Distance from closest: ${closestPoint} to node: ${position}  : $distanceFromClosest "
            )
            if (distanceFromClosest >= minDistanceMeters) {
                targetPoint = position
                break
            }
        }
        if (targetPoint != null) {
            Log.d(TAG, "> Target node found at position: ${targetPoint}")
            pointArrowToPosition(Position(targetPoint.x, targetPoint.y, targetPoint.z))
        } else {
            Log.w(
                TAG,
                "> No node found at least $minDistanceMeters meters away from the closest node."
            )
        }
    }

    private fun hasToUpdateArrowTarget(): Boolean {
        if (targetArrow != null) {
            val distanceToCamera = calculate2DDistance(
                Vector3(
                    sceneView.cameraNode.worldPosition.x,
                    sceneView.cameraNode.worldPosition.y,
                    sceneView.cameraNode.worldPosition.z
                ), Vector3(targetArrow!!.x, targetArrow!!.y, targetArrow!!.z)
            )
            if (distanceToCamera < DIRECTION_ARROW_TARGET_DISTANCE / 2 || distanceToCamera > DIRECTION_ARROW_TARGET_DISTANCE * 2) {
                return true
            }
        }
        return false
    }

    // points arrow to position in arCoordinates
    private fun pointArrowToPosition(targetARPosition: Position) {
        targetArrow = targetARPosition
        arrowNode?.lookAt(targetARPosition, smooth = true)
    }

    suspend fun loadTextureFromUrlAsync(context: Context, imageUrl: String): Texture? {
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

    fun drawDiskWithImage(poiAR: PoiAR, arPosition: Position, poiCategory: PoiCategory) {

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
            diskNode.position = Position(0f, -0.5f, 0f)
            if (poiAR.node != null) {
                poiAR.node!!.addChildNode(diskNode)
                poiAR.geometryNode = diskNode
            }
        } else {
            Log.e(TAG, ">> Failed to load texture.")
        }
    }

    private suspend fun loadPois() {
        if (::currentPosition.isInitialized && this.currentPosition != null && ::pois.isInitialized && pois.isNotEmpty()) {
            var nearPois = poiUtils.filterPoisByDistanceAndFloor(pois, currentPosition, 50)
            var arcorePositions = generateARCorePositions(
                nearPois, currentPosition
            ) { poi -> poi.position.cartesianCoordinate }
            logExecutionTime(" >> add pois to scene ") {
                addPoisToScene(nearPois, arcorePositions)
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
            sceneView.addChildNode(arrowNode!!)
        }
    }

    fun unload() {
        viewAttachmentManager.onPause()
        arrowNode?.let { sceneView.removeChildNode(it) }
        arrowNode = null
        clearPoiNodes()
        makeRouteInvisible()
        clearRouteNodes()
        clearModels()
        pois = emptyList()
        poisTexturesMap.clear()
        sceneView.clearChildNodes()
        diskGeometry?.let { diskGeometry = null }
        stopModelProximityCheck()
    }


    fun clearAllNodes(node: Node) {
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

    private fun clearRouteNodes() {
        for (routeNode in routeNodes) {
            routeNode.parent = null
        }
        sceneView.removeChildNodes(routeNodes)
        routeNodes.clear()
    }

    private fun clearModels() {
        for (fenceModel in fenceModels) {

            fenceModel.value.removeFromScene(sceneView)
        }
        fenceModels.clear()
    }

    private fun clearRoute() {
        route = Route()
    }

    // Navigation listener
    override fun onStart(route: Route) {        // TODO: Esto no se va a llamar
        Log.w(TAG, ">>>>> on start navigation listener")
        setRoute(route)
        updateRouteNodes()
        updateArrowTarget()
    }

    override fun onProgress(navigationProgress: NavigationProgress?) {
        Log.w(TAG, ">> Situm navigation progress: ${navigationProgress.toString()}")

        navigationProgress?.segments?.get(0)?.let { setCurrentSegment(it) }
        if (hasToUpdateArrowTarget()) {
            updateArrowTarget()
        }
        return
    }

    override fun onUserOutsideRoute() {
        Log.w(TAG, ">> Situm navigation user out of routes")
    }


    override fun onCancellation() {
        Log.w(TAG, ">> Situm navigation onCancellation")
        makeRouteInvisible()
        super.onCancellation()
    }

    override fun onDestinationReached(route: Route?) {
        Log.w(TAG, ">> Situm navigation on destination reached")
        makeRouteInvisible()
        sendArGoneCallback?.onARGoneRequired()
        super.onDestinationReached(route)
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
                updateRouteNodes()
            }
            logExecutionTime(" >> update target arrow  ") {
                updateTargetArrowOnARRoute(DIRECTION_ARROW_TARGET_DISTANCE)
            }
            isRedrawing = false
        }
    }

    fun updateArrowTarget() {
        updateTargetArrowOnARRoute(DIRECTION_ARROW_TARGET_DISTANCE)
    }

    fun getCurrentStatusLog(): String {
        return arQuality.getCurrentStatusLog()
    }

    fun getVisualOdometry(): String {
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

    fun updateVisualOdometry() {
        val externalAR = ExternalArData.Builder().rawJsonString(getVisualOdometry()).build()
        SitumSdk.locationManager().addExternalArData(externalAR)
    }

    fun switchShowRouteOnAR() {
        hasToShowDebugRoute = !hasToShowDebugRoute
        if (!hasToShowDebugRoute) {
            makeRouteInvisible()
        }
        Log.d(TAG, ">> hasToShowRoute: $hasToShowDebugRoute")
    }

    override fun onEnteredGeofences(geofences: MutableList<Geofence>?) {
        if (onDebug) {
            Toast.makeText(context, "Enter Geofence!", Toast.LENGTH_SHORT).show()
        }

        geofences?.forEach { geofence ->
            geofence.customFields?.forEach { customField ->
                if (customField.key == "ar_metadata") {
                    try {
                        val extractedData = parseGeofenceArMetadata(customField)

                        extractedData.forEach { data ->
                            handleArMetadata(data, geofence.name)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing geofence metadata: ${e.message}", e)
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
            geofence.customFields?.forEach { customField ->
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
                        Log.e(TAG, "Error processing geofence metadata: ${e.message}", e)
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

        Log.d(TAG, "Nombre: $modelName, URL: ${data["url"]}, Escala: $scale, Coordenadas: $coordinates")

        val existingModel = fenceModels[modelName]

        if (existingModel != null) {
            updateExistingModel(existingModel, height)
        } else {
            val modelResId = activity?.resources?.getIdentifier(modelName, "raw", activity?.packageName)
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
    private fun updateExistingModel(existingModel: SitumARModel, height: Float) {
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
                addModelToScene(it, modelName, scale, height, geofenceName)
            }
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
            Log.e(TAG, "Invalid URL for model: $modelName")
            return
        }

        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
            val modelNode = fetchAndBuildModelNode(modelUrl, scale)
            modelNode?.let {
                addModelToScene(it, modelName, scale, height, geofenceName)
            }
        }
    }

    /**
     * Adds a new AR model to the scene and updates the fenceModels map.
     */
    private fun addModelToScene(
        modelNode: ModelNode,
        modelName: String,
        scale: Float,
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
        val json = JsonParser.parseString(cf.value.toString()).asJsonObject
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



    fun startModelProximityCheck() {
        proximityCheckRunnable = object : Runnable {
            override fun run() {
                val userPosition = sceneView.cameraNode.worldPosition
                val visiblePositions = getVisibleModelPositions(fenceModels)
                val hasNearbyModels = visiblePositions.any { position ->
                    distanceBetween(userPosition, position) < minDistanceThresholdToRegenerateModels
                }

                if (!hasNearbyModels) {
                    regenerateModelsNearUser(userPosition)
                }

                // Reprogramar la verificación
                handler.postDelayed(this, checkInterval)
            }
        }
        proximityCheckRunnable?.let { handler.post(it) }
    }
    fun stopModelProximityCheck() {
        proximityCheckRunnable?.let { handler.removeCallbacks(it) }
        proximityCheckRunnable = null // Liberar la referencia
    }

    private fun regenerateModelsNearUser(userPosition: Position) {
        fenceModels.forEach { (modelName, model) ->
            if (model.modelNode.isVisible) {
                updateExistingModel(model, model.modelNode.worldPosition.y)
            }
        }
    }



    fun isDebugMode(): Boolean {
        return onDebug;
    }

    fun setDebugMode(debug: Boolean) {
        onDebug = debug;
    }
}