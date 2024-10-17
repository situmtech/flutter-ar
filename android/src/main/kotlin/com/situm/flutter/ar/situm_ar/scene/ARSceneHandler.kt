package com.situm.flutter.ar.situm_ar.scene

import android.app.Activity
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import android.webkit.WebView
import android.widget.TextView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.google.android.filament.Texture
//import com.google.android.filament.Material
import com.google.ar.core.Anchor
import com.google.ar.core.Plane
import com.google.ar.sceneform.rendering.ViewAttachmentManager
import com.google.ar.sceneform.rendering.ViewRenderable
import com.situm.flutter.ar.situm_ar.CustomARSceneView
import com.situm.flutter.ar.situm_ar.R
import dev.romainguy.kotlin.math.Float3
import es.situm.sdk.error.Error
import es.situm.sdk.location.LocationListener
import es.situm.sdk.location.LocationStatus
import es.situm.sdk.model.cartography.BuildingInfo
import es.situm.sdk.model.cartography.Poi
import es.situm.sdk.model.cartography.PoiCategory
import es.situm.sdk.model.cartography.Point
import es.situm.sdk.model.directions.Route
import es.situm.sdk.model.directions.RouteSegment
import es.situm.sdk.model.location.CartesianCoordinate
import es.situm.sdk.model.location.Location
import es.situm.sdk.model.navigation.NavigationProgress
import es.situm.sdk.navigation.NavigationListener
import io.github.sceneview.ar.arcore.getUpdatedPlanes
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.collision.Vector3
import io.github.sceneview.geometries.Cylinder
import io.github.sceneview.geometries.Sphere
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.math.Color
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.node.GeometryNode
import io.github.sceneview.node.ModelNode
import io.github.sceneview.node.Node
import io.github.sceneview.node.ViewNode
import io.github.sceneview.texture.setBitmap
import io.github.sceneview.utils.getResourceUri
import kotlinx.coroutines.launch

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL
import java.nio.ByteBuffer
const val DIRECTION_ARROW_TARGET_DISTANCE = 6f

class ARSceneHandler(
    private val activity: Activity,
    private val lifecycle: Lifecycle,
):NavigationListener,LocationListener {
    companion object {
        const val TAG = "Situm> AR>"
    }

    private val dashboardDomain: String = "https://dashboard.situm.com"

    private lateinit var targetArrowSitumCoordinates: Point
    private val context: Context = activity

    private var arrowNode: ModelNode? = null
    private var targetArrow: Position? = null
    private var anchorNode: AnchorNode? = null

    private lateinit var pois: List<Poi>
    val poisTexturesMap = mutableMapOf<String, Texture?>()
    private var poisNodes: MutableList<ViewNode> = mutableListOf()
    private var poisDiskNodes: MutableList<GeometryNode> = mutableListOf()

    private lateinit var currentSegment: RouteSegment
    private lateinit var route: Route
    private var routeNodes: MutableList<GeometryNode> = mutableListOf()
    private lateinit var currentTargetNodeGeometry: GeometryNode
    private lateinit var currentProjectedNodeGeometry: GeometryNode

    private lateinit var buildingInfo: BuildingInfo
    private lateinit var currentPosition: Location


    private lateinit var sceneView: CustomARSceneView
    private lateinit var viewAttachmentManager: ViewAttachmentManager

    //var diskModel: ModelNode? = null


    fun setRoute(route: Route) {
        this.route = route
    }
    private fun setCurrentSegment(routeSegment: RouteSegment) {
        this.currentSegment = routeSegment
    }

    fun setPois(pois: List<Poi>) {
        this.pois = pois
    }

    fun loadPoiImages(){
        for (poi in pois){
            CoroutineScope(Dispatchers.Main).launch {
                Log.d(TAG, "> Situm: To download texture from : ${dashboardDomain+poi.category.unselectedIconUrl.value.toString()}")
                if (!poisTexturesMap.containsKey(poi.category.identifier)) {
                    val texture = loadTextureFromUrlAsync(context,
                        dashboardDomain+poi.category.unselectedIconUrl.value.toString())
                    if (texture != null) {
                        poisTexturesMap[poi.category.identifier] = texture
                    }
                }
            }
        }
    }


    fun setCurrentLocation(location: Location) {
        Log.d(TAG, "Situm location $location")
        if (::currentPosition.isInitialized && this.poisNodes.isEmpty()){
            Log.w(TAG,">> LOAD POIS")
            loadPois()
        }else{
            Log.w(TAG,">> NOT LOAD POIS: ${this.poisNodes.size}")
        }
        // if floor change, redraw
        if (::currentPosition.isInitialized && this.currentPosition.floorIdentifier != location.floorIdentifier) {
            loadPois()
            updateRouteNodes()
        }
        this.currentPosition = location
    }

    fun setBuildingInfo(buildingInfo: BuildingInfo) {
        Log.d(TAG,"set building info : $buildingInfo")
        this.buildingInfo = buildingInfo
        setPois(buildingInfo.indoorPOIs as List<Poi>)
        loadPoiImages()
    }


    fun setupSceneView(sceneView: CustomARSceneView) {

        viewAttachmentManager = ViewAttachmentManager(context, sceneView)
        viewAttachmentManager.onResume()

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
//                (activity as? LifecycleOwner)?.lifecycleScope?.launch {
//                    diskModel = buildModelNode(R.raw.disc)
//                }
            }
            onTrackingFailureChanged = { reason ->
                Log.i(TAG, "onTrackingFailureChanged: $reason")
            }
            onSessionUpdated = { _, frame ->
                if (anchorNode == null) {
                    frame.getUpdatedPlanes()
                        .firstOrNull { it.type == Plane.Type.HORIZONTAL_UPWARD_FACING }
                        ?.let { plane ->
                            addAnchorNode(plane.createAnchor(plane.centerPose))
                            //loadTextViewInAR(plane.centerPose.position, "Dance")
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
                        val cameraDirection = io.github.sceneview.collision.Quaternion.rotateVector(
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
                }
            }
        }
        //
//        var position =
//            io.github.sceneview.math.Position(0.0f, 0.0f, -1.0f) // 1 metro frente a la cámara
        //loadTextViewInAR(position, "init Text")

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
                    y = 0f
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

    private fun addPoisToScene(pois: List<Poi>, arcorePositions: List<Vector3>) {
        clearPoiNodes()
        for (i in pois.indices) {
            val poi = pois[i]
            val arcorePosition = arcorePositions[i]
            arcorePosition.x
            arcorePosition.y
            arcorePosition.z

            val position = Position(arcorePosition.x, arcorePosition.y, arcorePosition.z)

            Log.w(
                TAG,
                "> Situm . Adding poi to scene: ${poi.name} , ${poi.infoHtml}, ${poi.cartesianCoordinate} "
            )

            loadTextViewInAR(
                position, poi.name
            )

            val positionDisk = Position(arcorePosition.x, arcorePosition.y-0.5f, arcorePosition.z)

           drawDiskWithImage(positionDisk, poi.category)
//            if (poi.infoHtml.isNotEmpty()) {
//                loadWebViewInAR(
//                    Position(arcorePosition.x, arcorePosition.y - 1, arcorePosition.z), poi.infoHtml
//                )
//            }
        }
    }

    private fun loadTextViewInAR(position: Position, textString: String) {

        val textView = TextView(context).apply {
            text = textString
            textSize = 50f
            setTextColor(android.graphics.Color.WHITE) // Establece el color del texto
        }
        ViewRenderable.builder().setView(context, textView).build(sceneView.engine)
            .thenAccept { viewRenderable ->
                var viewNode =
                    ViewNode(sceneView.engine, sceneView.modelLoader, viewAttachmentManager)
                viewNode.setRenderable(viewRenderable)

                viewNode.position = position
                viewNode.lookAt(sceneView.cameraNode)
                viewNode.scale = Float3(-1f, 1f, 1f) // Inv. Needed to show text correctly
                poisNodes.add(viewNode)
                sceneView.addChildNode(viewNode)
            }.exceptionally { throwable ->
                throwable.printStackTrace()
                null
            }
    }


    private fun loadWebViewInAR(position: Position, htmlContent: String) {

        val webView = WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.loadWithOverviewMode = true
            settings.useWideViewPort = true
            settings.mediaPlaybackRequiresUserGesture = false


            loadDataWithBaseURL(null, htmlContent, "text/html", "utf-8", null)
//            setOnTouchListener { v, event ->
//                v.performClick()
//                false
//            }
        }

        ViewRenderable.builder().setView(context, webView).build(sceneView.engine)
            .thenAccept { viewRenderable ->
                val viewNode =
                    ViewNode(sceneView.engine, sceneView.modelLoader, viewAttachmentManager)

                viewNode.setRenderable(viewRenderable)

                viewNode.position = position
                viewNode.lookAt(sceneView.cameraNode)
                viewNode.scale = Float3(-1f, 1f, 1f)
                poisNodes.add(viewNode)

                sceneView.addChildNode(viewNode)
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

            val pathInterpolated = interpolatePositions(arCorePositionsForPoints, 1.0f)
            addSpheresToScene(pathInterpolated)
        }
        //updateTargetArrowOnARRoute(3f)
    }

    private fun addSpheresToScene(positions: List<Vector3>, sphereRadius: Float = 0.1f) {
        // force clear previous route if exists
        clearRouteNodes()

        val material = MaterialLoader(sceneView.engine, context).createColorInstance(
            Color(
                0f, 0f, 1f, 0.5f
            )
        )
        val sphereGeometry =
            Sphere.Builder().radius(sphereRadius).center(Position(0f,0f,0f)).build(sceneView.engine)
        Log.d(TAG, "> Situm add spheres to scene")
        positions.forEach { position ->
            Log.d(TAG, "> Situm add spheres to scene: $position")
            val center = Position(position.x, position.y, position.z)
            val sphereNode = GeometryNode(sceneView.engine, sphereGeometry, material)
            sphereNode.worldPosition = center
            routeNodes.add(sphereNode)
        }
        sceneView.addChildNodes(routeNodes)
    }

    // from current AR position and AR RouteNodes, projects position on route and finds next node at n distance (?)
    private fun updateTargetArrowOnARRoute(minDistanceMeters: Float) {
        val cameraPosition = sceneView.cameraNode.worldPosition
        var closestNode: GeometryNode? = null
        var minDistanceToCamera = Float.MAX_VALUE

        //  Find closest node
        for (node in routeNodes) {
            Log.d(TAG,"> node: ${node.worldPosition} / ${node.position}")
            val nodePosition = node.worldPosition
            val distanceToCamera = calculate2DDistance(
                Vector3(cameraPosition.x, cameraPosition.y, cameraPosition.z),
                Vector3(nodePosition.x, nodePosition.y, nodePosition.z)
            )

            if (distanceToCamera < minDistanceToCamera) {
                minDistanceToCamera = distanceToCamera
                closestNode = node
            }
        }
        if (closestNode == null) {
            Log.w(TAG, "> No closest node found.")
            return
        } else{
            Log.w(TAG,"< Closest node: ${closestNode.worldPosition}, ${closestNode.position}")
        }

        drawCurrentProjectedPosition(closestNode.worldPosition)
        var targetNode: GeometryNode? = null

        for (i in routeNodes.indexOf(closestNode) until routeNodes.size) {
            val node = routeNodes[i]
            val distanceFromClosest = calculate2DDistance(
                Vector3(
                    closestNode.worldPosition.x,
                    closestNode.worldPosition.y,
                    closestNode.worldPosition.z
                ), Vector3(node.worldPosition.x, node.worldPosition.y, node.worldPosition.z)
            )
            Log.d(TAG,"> Distance from closest: ${closestNode.worldPosition} to node: ${node.worldPosition}  : $distanceFromClosest ")
            if (distanceFromClosest >= minDistanceMeters) {
                targetNode = node
                break
            }
        }
        if (targetNode != null) {
            Log.d(TAG, "> Target node found at position: ${targetNode.worldPosition}")
            pointArrowToPosition(targetNode.worldPosition)
        } else {
            Log.w(
                TAG, "> No node found at least $minDistanceMeters meters away from the closest node."
            )
        }
    }
    private fun hasToUpdateArrowTarget(): Boolean {
        if (targetArrow!=null){
            val distanceToCamera = calculate2DDistance(
                Vector3(
                    sceneView.cameraNode.worldPosition.x,
                    sceneView.cameraNode.worldPosition.y,
                    sceneView.cameraNode.worldPosition.z
                ),
                Vector3(targetArrow!!.x, targetArrow!!.y, targetArrow!!.z)
            )
            if (distanceToCamera < DIRECTION_ARROW_TARGET_DISTANCE/2 || distanceToCamera > DIRECTION_ARROW_TARGET_DISTANCE * 2){
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
        if (::currentTargetNodeGeometry.isInitialized) {
            sceneView.removeChildNode(currentTargetNodeGeometry)
        }
        currentTargetNodeGeometry = drawSphereOnPosition(targetARPosition,Color(0f, 1f, 0f, 0.8f))
    }

    private fun drawCurrentProjectedPosition(projectedARPosition: Position) {
        if (::currentProjectedNodeGeometry.isInitialized) {
            sceneView.removeChildNode(currentProjectedNodeGeometry)
        }
        currentProjectedNodeGeometry = drawSphereOnPosition(projectedARPosition,Color(1f, 1f, 0f, 0.8f))
    }

    private fun drawSphereOnPosition(arPosition: Position, color: Color): GeometryNode{
        val sphereGeometry = Sphere.Builder().radius(0.15f).center(arPosition).build(sceneView.engine)
        val material =
            MaterialLoader(sceneView.engine, context).createColorInstance(color)
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
                Texture.Builder()
                    .width(bitmap.width)
                    .height(bitmap.height)
                    .build(sceneView.engine).apply {
                        setImage(
                            sceneView.engine,
                            0,
                            Texture.PixelBufferDescriptor(
                                buffer,
                                Texture.Format.RGBA,
                                Texture.Type.UBYTE
                            )
                        )
                    }
            } catch (e: Exception) {
                Log.e(TAG,">> Exceptiom loading texture : $e")
                e.printStackTrace()
                null
            }
        }
    }

//    // Función para dibujar el modelo con diferentes texturas
//    fun drawDiskWithImage(arPosition: Position, poiCategory: PoiCategory) {
//        // Verifica si el modelo ya fue cargado
//        if (diskModel == null) {
//            Log.e(TAG, ">> Disk model not loaded yet.")
//            return
//        }
//
//        val texture = poisTexturesMap[poiCategory.identifier]
//        if (texture != null) {
//            // Clonar el nodo del modelo cargado
//            val clonedDiskNode = diskModel?.modelInstance?.let { modelInstance ->
//                ModelNode(
//                    modelInstance = modelInstance,
//                    scaleToUnits = 0.5f,
//                    centerOrigin = Position(y = -0.5f)
//                ).apply {
//                    isEditable = true
//                }
//            }
//
//            if (clonedDiskNode != null) {
//                // Cargar el material con la textura
//                val materialInstance =
//                    MaterialLoader(sceneView.engine, context).createTextureInstance(texture, true)
//
//                // Asignar el material clonado al modelo
//                //clonedDiskNode.modelInstance?.material = materialInstance
//                clonedDiskNode.modelInstance?.asset?.let { asset ->
//                    for (entity in asset.entities) {
//                        // Verificamos si el entity tiene un material asociado
//                        val material = sceneView.engine.renderableManager.getMaterialInstanceAt(entity, 0)
//                        if (material != null) {
//                            // Asignamos la nueva textura al material
//                            material.setTexture("baseColorMap", texture)
//                        }
//                    }
//                }
//                // Ajustar la posición en AR
//                clonedDiskNode.worldPosition = arPosition
//                clonedDiskNode.lookAt(sceneView.cameraNode)
//
//                // Añadir el nodo clonado a la escena
//                sceneView.addChildNode(clonedDiskNode)
//
//                // Guardar el nodo si es necesario
//               // poisDiskNodes.add(clonedDiskNode)
//
//                Log.d(TAG, ">> Disk node added to scene with texture.")
//            }
//        } else {
//            Log.e(TAG, ">> Failed to load texture.")
//        }
//    }



    //TODO: Que no aparezcan giradas y que miren siempre a camara.
    fun drawDiskWithImage(arPosition: Position, poiCategory: PoiCategory) {

        val diskGeometry = Cylinder.Builder()
            .radius(0.5f)
            .height(0.01f)
            .build(sceneView.engine)

        val texture =  poisTexturesMap[poiCategory.identifier]
        if (texture != null) {
            // Crear la geometría del cilindro (simulando un disco)


            // Cargar el material con la textura
            val materialInstance =
                MaterialLoader(sceneView.engine, context).createTextureInstance(texture, true)

            // Crear el nodo con el disco (cilindro plano) y el material con la textura
            val diskNode = GeometryNode(sceneView.engine, diskGeometry, materialInstance)
            //diskNode.worldPosition = arPosition
            diskNode.rotation = Rotation(-90f, 0f, 0f)
            var node: Node = Node(sceneView.engine)
            node.addChildNode(diskNode)
            node.worldPosition = arPosition
            node.lookAt(sceneView.cameraNode)
            poisDiskNodes.add(diskNode)




            // Añadir el nodo a la escena
            sceneView.addChildNode(node)
            Log.d(TAG, ">> Disk added to scene with texture.")
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

    private fun loadPois() {
        if (::currentPosition.isInitialized && this.currentPosition != null && ::pois.isInitialized && pois.isNotEmpty()) {
            var nearPois = filterPoisByDistanceAndFloor(pois, currentPosition, 50)
            Log.d(TAG, "> Situm: load  pois: $nearPois")
            var arcorePositions = generateARCorePositions(
                nearPois, currentPosition
            ) { poi -> poi.position.cartesianCoordinate }
            addPoisToScene(nearPois, arcorePositions)
        }
    }


    private fun multiplyVectorScalar(vector: Vector3, scalar: Float): Vector3 {
        return Vector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }


    private fun addVectors(vector1: Vector3, vector2: Vector3): Vector3 {
        return Vector3(vector1.x + vector2.x, vector1.y + vector2.y, vector1.z + vector2.z)
    }

    private fun addAnchorNode(anchor: Anchor) {
        sceneView.addChildNode(AnchorNode(sceneView.engine, anchor).apply {
            isEditable = true
            (activity as? LifecycleOwner)?.lifecycleScope?.launch {
                buildModelNode(R.raw.eren_hiphop_dance)?.let { addChildNode(it) }
            }
            anchorNode = this
        })
    }


    private suspend fun buildModelNode(resId: Int): ModelNode? {
        return sceneView.modelLoader.loadModelInstance(activity.getResourceUri(resId))
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
        clearRouteNodes()
    }

    private fun clearPoiNodes() {

        for (poiNode in poisNodes) {
            poiNode.parent = null
        }
        sceneView.removeChildNodes(poisNodes)
        poisNodes.clear()

        for (poiNode in poisDiskNodes) {
            poiNode.parent = null
        }
        sceneView.removeChildNodes(poisDiskNodes)
        poisDiskNodes.clear()
    }

    private fun clearRouteNodes() {
        for (routeNode in routeNodes) {
            routeNode.parent = null
        }
        sceneView.removeChildNodes(routeNodes)
        routeNodes.clear()
    }

    private fun clearRoute() {
        route = Route()
    }

    // Navigation listener
    override fun onStart(route: Route) {        // TODO: Esto no se va a llamar
        setRoute(route)
        updateRouteNodes()
        updateArrowTarget()
    }

    override fun onProgress(navigationProgress: NavigationProgress?) {
        Log.d(TAG, ">> Situm navigation progress: ${navigationProgress.toString()}")

        navigationProgress?.segments?.get(0)?.let { setCurrentSegment(it) }
        if(hasToUpdateArrowTarget()){
            updateArrowTarget()
        }
        return
    }

    override fun onUserOutsideRoute() {
        Log.w(TAG, ">> Situm navigation user out of routes")
    }


    override fun onCancellation() {
        Log.w(TAG, ">> Situm navigation onCancellation")
        clearRouteNodes()
        clearRoute()
        super.onCancellation()
    }

    override fun onDestinationReached(route: Route?) {
        Log.w(TAG, ">> Situm navigation on destination reached")
        clearRouteNodes()
        clearRoute()
        super.onDestinationReached(route)
    }
    // Location Listener

    override fun onLocationChanged(location: Location) {
        this.setCurrentLocation(location)
    }

    override fun onStatusChanged(p0: LocationStatus) {

    }

    override fun onError(p0: Error) {

    }

    // callable from dart
    fun worldRedraw() {
        loadPois()
        updateRouteNodes()
        updateTargetArrowOnARRoute(DIRECTION_ARROW_TARGET_DISTANCE)
    }

    fun updateArrowTarget() {
        updateTargetArrowOnARRoute(DIRECTION_ARROW_TARGET_DISTANCE)
    }

}