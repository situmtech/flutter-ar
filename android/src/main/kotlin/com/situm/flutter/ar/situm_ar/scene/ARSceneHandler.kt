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
import com.google.gson.JsonObject
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
import es.situm.sdk.model.cartography.Point
import es.situm.sdk.model.directions.Route
import es.situm.sdk.model.directions.RouteSegment
import es.situm.sdk.model.location.CartesianCoordinate
import es.situm.sdk.model.location.Location
import es.situm.sdk.model.navigation.NavigationProgress
import es.situm.sdk.navigation.NavigationListener
import io.github.sceneview.ar.node.AnchorNode
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

interface ARControllerCallback {
    fun sendARGone()
}

class ARSceneHandler(
    private val activity: Activity,
    private val lifecycle: Lifecycle,
) : NavigationListener, LocationListener, GeofenceListener {
    companion object {
        const val TAG = "Situm> AR>"
    }

    private var onDebug: Boolean = true
    private var callback: ARControllerCallback? = null

    private var hasToCalculateRoute = 10
    private var hasToShowDebugRoute: Boolean = false
    private val dashboardDomain: String = "https://dashboard.situm.com"

    private lateinit var targetArrowSitumCoordinates: Point
    private val context: Context = activity

    private var isRedrawing: Boolean = false        // not allow to redraw if is already redrawing

    private var arQuality: ARQuality = ARQuality()
    private var poiUtils: PoiUtils = PoiUtils()

    private var arrowNode: ModelNode? = null
    private var targetArrow: Position? = null

    private var anchorNode: AnchorNode? = null
    private var diskGeometry: Geometry? = null


    private lateinit var pois: List<Poi>
    val poisAR = mutableMapOf<String, PoiAR>()
    val fenceModels = mutableMapOf<String, SitumARModel>()
    val poisTexturesMap = mutableMapOf<String, Texture?>()

    private lateinit var currentSegment: RouteSegment
    private var routePointsAR: MutableList<Vector3> = mutableListOf()
    private lateinit var route: Route

    private val routeNodes: MutableList<Node> = mutableListOf()     // only for debug

    private lateinit var currentProjectedNodeGeometry: GeometryNode

    private lateinit var buildingInfo: BuildingInfo
    private lateinit var currentPosition: Location
    private var lastTimestampRedraw: Long = 0

    private lateinit var sceneView: CustomARSceneView
    private lateinit var viewAttachmentManager: ViewAttachmentManager

    fun setCallback(callback: ARControllerCallback) {
        this.callback = callback
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

        //drawCurrentProjectedPosition(Position(closestPoint.x,closestPoint.y,closestPoint.z))

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
        // debug
//        if (!::currentTargetNodeGeometry.isInitialized || currentTargetNodeGeometry == null) {
//            val sphereGeometry =
//                Sphere.Builder().radius(0.15f).build(sceneView.engine)
//            val material = MaterialLoader(sceneView.engine, context).createColorInstance(
//                Color(
//                    0f,
//                    1f,
//                    0f,
//                    0.8f
//                )
//            )
//            targetNode = GeometryNode(sceneView.engine, sphereGeometry, material)
//            sceneView.addChildNode(targetNode!!)
//        } else {
//            targetNode!!.worldPosition = targetARPosition
//        }

    }

    private fun drawCurrentProjectedPosition(projectedARPosition: Position) {
        if (::currentProjectedNodeGeometry.isInitialized) {
            sceneView.removeChildNode(currentProjectedNodeGeometry)
        }
        currentProjectedNodeGeometry =
            drawSphereOnPosition(projectedARPosition, Color(1f, 1f, 0f, 0.8f))
    }

    private fun drawSphereOnPosition(arPosition: Position, color: Color): GeometryNode {
        val sphereGeometry =
            Sphere.Builder().radius(0.15f).center(arPosition).build(sceneView.engine)
        val material = MaterialLoader(sceneView.engine, context).createColorInstance(color)
        val sphereNode = GeometryNode(sceneView.engine, sphereGeometry, material)
        sceneView.addChildNode(sphereNode)
        return sphereNode
    }

    /////////////////////

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
//            poiAR.node?.worldPosition = arPosition
//            poiAR.node?.lookAt(sceneView.cameraNode)
            poiAR.node?.isVisible = true
            return
        }

        val texture = poisTexturesMap[poiCategory.identifier]
        if (texture != null && diskGeometry != null) {
            Log.w(TAG, ">>>>>>>>>>> Disc geometry: ${diskGeometry!!.indices.size}")
            val materialInstance =
                MaterialLoader(sceneView.engine, context).createTextureInstance(
                    texture,
                    true,
                    0.1f,
                    0.8f,
                    0.02f
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


    // receives a position in situm coordinates, converts it to ar coordinates and points arrow towards it.
    private fun pointArrowToSitumPosition(fromPoint: Point?) {
        val arCorePosition = fromPoint?.let {
            generateARCorePositions(
                listOf(it),  // Pasar una lista con un único punto
                currentPosition
            ) { point -> point.cartesianCoordinate }
        }
        var targetArrow = arCorePosition?.get(0)?.let { Position(it.x, it.y, it.z) }
        if (targetArrow != null) {
            pointArrowToPosition(targetArrow)
        }
    }

    private suspend fun loadPois() {
        Log.d(TAG, ">> Load pois 1")
        if (::currentPosition.isInitialized && this.currentPosition != null && ::pois.isInitialized && pois.isNotEmpty()) {
            Log.d(TAG, ">> Load pois 2")
            var nearPois = poiUtils.filterPoisByDistanceAndFloor(pois, currentPosition, 50)
            Log.d(TAG, ">> Load pois 3")
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
        anchorNode?.let { sceneView.removeChildNode(it) }
        anchorNode = null
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
        callback?.sendARGone()
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
                    Toast.makeText(context, "Refresh!", Toast.LENGTH_SHORT).show()
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
            geofence.customFields?.forEach { cf ->
                if (cf.key == "ar_metadata_android") {
                    try {
                        val json = JsonParser.parseString(cf.value.toString()) as JsonObject
                        val modelName = json.get("name")?.asString
                            ?: throw IllegalArgumentException("No 'name' field in JSON")
                        val scale = json.get("scale")?.asFloat ?: 1f
                        val height = json.get("height")?.asFloat ?: 0f

                        Log.d(TAG, ">>>>>>> GEOFENCE JSON_ $modelName  $scale $height")

                        if (modelName.endsWith(".glb")) {
                            val modelNameWithoutExtension = modelName.removeSuffix(".glb")
                            val existingModel = fenceModels[modelNameWithoutExtension]

                            if (existingModel != null) {
                                existingModel.modelNode.worldPosition =
                                    getRandomPositionNearPosition(
                                        sceneView.cameraNode.worldPosition,
                                        2f,
                                        height
                                    )
                                existingModel.modelNode.isVisible = true
                            } else {
                                val modelResId = activity?.resources?.getIdentifier(
                                    modelNameWithoutExtension, "raw", activity?.packageName
                                )

                                Log.d(
                                    TAG,
                                    ">>>>>>>>>>>>>>>>>>>> $modelNameWithoutExtension $modelResId"
                                )

                                if (modelResId != null && modelResId != 0) {
                                    (activity as? LifecycleOwner)?.lifecycleScope?.launch {
                                        val modelNode = buildModelNode(modelResId, scale)
                                        Log.d(
                                            TAG,
                                            ">>>>>>>>>>>>>>>>>>>> Building model $modelResId   -> trexmodel ${R.raw.trex} / eren model ${R.raw.eren_hiphop_dance} / sad person ${R.raw.sad_person} ${R.raw.phoenix_bird} ${R.raw.hummingbird} ${R.raw.saturn}"
                                        )

                                        modelNode?.let {
                                            val situmARModel =
                                                SitumARModel(geofence.name, modelName, it)
                                            fenceModels[modelNameWithoutExtension] = situmARModel
                                            modelNode.worldPosition = getRandomPositionNearPosition(
                                                sceneView.cameraNode.worldPosition,
                                                2f,
                                                height
                                            )
                                            sceneView.addChildNode(it)

                                        }
                                    }
                                } else {
                                    Log.e(
                                        "GeofenceHandler",
                                        "Modelo no encontrado en R.raw: $modelNameWithoutExtension"
                                    )
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "> Error parsing JSON or invalid format: ${e.message}")
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
            geofence.customFields?.forEach { cf ->
                if (cf.key == "ar_metadata_android") {
                    try {
                        val json = JsonParser.parseString(cf.value.toString()) as JsonObject
                        val modelName = json.get("name")?.asString
                            ?: throw IllegalArgumentException("No 'name' field in JSON")
                        if (modelName.endsWith(".glb")) {
                            val modelNameWithoutExtension = modelName.removeSuffix(".glb")
                            fenceModels[modelNameWithoutExtension]?.let { model ->
                                //model.removeFromScene(sceneView)
                                model.modelNode.isVisible = false
                                //fenceModels.remove(cf.value)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(
                            TAG,
                            "> Error parsing JSON or invalid format: ${e.message}"
                        )
                    }
                }
            }
        }
    }
}