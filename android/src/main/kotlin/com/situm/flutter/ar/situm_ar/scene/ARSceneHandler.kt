package com.situm.flutter.ar.situm_ar.scene

import android.app.Activity
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import android.webkit.WebView
import android.widget.TextView
import android.widget.Toast
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
import kotlinx.coroutines.launch

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL
import java.nio.ByteBuffer

const val DIRECTION_ARROW_TARGET_DISTANCE = 6f

class ARSceneHandler(
    private val activity: Activity,
    private val lifecycle: Lifecycle,
) : NavigationListener, LocationListener {
    companion object {
        const val TAG = "Situm> AR>"
    }

    private val dashboardDomain: String = "https://dashboard.situm.com"

    private lateinit var targetArrowSitumCoordinates: Point
    private val context: Context = activity

    private var arQuality: ARQuality = ARQuality()
    private var poiUtils: PoiUtils = PoiUtils()

    private var arrowNode: ModelNode? = null
    private var targetArrow: Position? = null
    private var anchorNode: AnchorNode? = null
    private lateinit var diskGeometry: Geometry



    private lateinit var pois: List<Poi>
    val poisAR =  mutableMapOf<String,PoiAR>()

    val poisTexturesMap = mutableMapOf<String, Texture?>()
    //private val poisTextNodes: MutableList<ViewNode> = mutableListOf()
    //private val poisNodes: MutableList<Node> = mutableListOf()
    //private val poisDiskNodes: MutableList<GeometryNode> = mutableListOf()
    private val poisDiskModelNodes: MutableList<ModelNode> = mutableListOf()
    private val poiModelNode: MutableList<Node> = mutableListOf()

    private lateinit var currentSegment: RouteSegment
    private lateinit var route: Route

    //private var routeNodes: MutableList<GeometryNode> = mutableListOf()
    //private var routeNodes: MutableList<ModelNode> = mutableListOf()
    private var routeNodes: MutableList<Node> = mutableListOf()
    private lateinit var currentTargetNodeGeometry: GeometryNode
    private lateinit var currentProjectedNodeGeometry: GeometryNode

    private lateinit var buildingInfo: BuildingInfo
    private lateinit var currentPosition: Location
    private var lastTimestampRedraw: Long = 0

    private lateinit var sceneView: CustomARSceneView
    private lateinit var viewAttachmentManager: ViewAttachmentManager

    var diskModel: ModelNode? = null


    fun setRoute(route: Route) {
        this.route = route
    }

    private fun setCurrentSegment(routeSegment: RouteSegment) {
        this.currentSegment = routeSegment
    }

    fun setPois(pois: List<Poi>) {
        this.pois = pois
    }
    fun updatePoisAR(){
        for (poi in pois){
            poisAR.set(poi.identifier, PoiAR(poi))
        }
    }

    fun loadPoiImages() {
        for (poi in pois) {
            CoroutineScope(Dispatchers.Main).launch {
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
        Log.d(TAG, "Situm location $location")
//        if (::currentPosition.isInitialized && this.poisTextNodes.isEmpty()){
//            Log.w(TAG,">> LOAD POIS")
//            loadPois()
//        }else{
//            Log.w(TAG,">> NOT LOAD POIS: ${this.poisTextNodes.size}")
//        }
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
        sceneView.apply {
            Log.d(TAG, "Setup ARSceneView")
            planeRenderer.isEnabled = false
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
                Log.i(TAG, "onTrackingFailureChanged: $reason")
            }
            onSessionUpdated = { _, frame ->
                if (diskModel == null) {
                    (activity as? LifecycleOwner)?.lifecycleScope?.launch {
                        diskModel = buildModelNode(R.raw.disc, 0.5f)
                    }

                }
                if(!::diskGeometry.isInitialized){
                    diskGeometry = Cylinder.Builder().radius(0.5f).height(0.01f).build(sceneView.engine)
                }
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

    private suspend fun addPoisToScene(pois: List<Poi>, arcorePositions: List<Vector3>) {
        //clearPoiNodes()
        for (i in pois.indices) {
            poisAR.get(pois[i].identifier)
            //val poi = pois[i].identifier
            val arcorePosition = arcorePositions[i]
            arcorePosition.x
            arcorePosition.y
            arcorePosition.z

            val position = Position(arcorePosition.x, arcorePosition.y, arcorePosition.z)

            Log.w(
                TAG,
                "> Situm . Adding poi to scene: ${poisAR.get(pois[i].identifier)?.poi?.name} , ${poisAR.get(pois[i].identifier)?.poi?.infoHtml}, ${poisAR.get(pois[i].identifier)?.poi?.cartesianCoordinate} "
            )
            withContext(Dispatchers.Main) {
                poisAR.get(pois[i].identifier)?.let {
                    loadTextViewInAR(
                        it,
                        position, poisAR.get(pois[i].identifier)!!.poi.name
                    )
                }
            }
            val positionDisk = Position(arcorePosition.x, arcorePosition.y - 0.5f, arcorePosition.z)

            poisAR.get(pois[i].identifier)?.poi?.let { drawDiskWithImage(poisAR.get(pois[i].identifier)!!,positionDisk, it.category) }
            //drawDiskWithImage(positionDisk, poi.category)
//            if (poi.infoHtml.isNotEmpty()) {
//                loadWebViewInAR(
//                    Position(arcorePosition.x, arcorePosition.y - 1, arcorePosition.z), poi.infoHtml
//                )
//            }
        }
    }

    private fun loadTextViewInAR(poiAR: PoiAR, position: Position, textString: String) {

        if (poiAR.viewNode!=null){
            Log.e(TAG, ">> YA EXISTE POI VIEWNODE")
            poiAR.viewNode!!.position = position
            poiAR.viewNode!!.lookAt(sceneView.cameraNode)
            poiAR.viewNode!!.scale = Float3(-1f, 1f, 1f)
            return

        }
        val textView = TextView(context).apply {
            text = textString
            textSize = 50f
            setTextColor(android.graphics.Color.WHITE)
        }
        ViewRenderable.builder().setView(context, textView).build(sceneView.engine)
            .thenAccept { viewRenderable ->
                var viewNode =
                    ViewNode(sceneView.engine, sceneView.modelLoader, viewAttachmentManager)
                viewNode.setRenderable(viewRenderable)

                viewNode.position = position
                viewNode.lookAt(sceneView.cameraNode)
                viewNode.scale = Float3(-1f, 1f, 1f) // Inv. Needed to show text correctly
                //poisTextNodes.add(viewNode)
                poiAR.viewNode = viewNode
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
                //poisTextNodes.add(viewNode)

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
    }

    private fun addSpheresToScene(positions: List<Vector3>, sphereRadius: Float = 0.3f) {
        // Forzar la limpieza de la ruta anterior si existe
        clearRouteNodes()

        // Lanzar una coroutine en el contexto del ciclo de vida de la actividad
        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
            positions.forEach { position ->
                Log.d(TAG, "> Situm add spheres to scene: $position")

                // Crear un nuevo modelo para cada posición
//                val modelNode = buildModelNode(R.raw.eren_hiphop_dance, sphereRadius)
//                modelNode?.let {
                    // Crear un nuevo nodo para cada posición
                    val node = Node(sceneView.engine).apply {
                        worldPosition = Position(position.x, position.y, position.z)
//                        addChildNode(it) // Agregar el modelo como hijo del nodo
                    }

                    routeNodes.add(node) // Agregar a la lista de nodos
//                }
            }

            // Añadir todos los nodos a la escena de una vez
            sceneView.addChildNodes(routeNodes)
        }
    }

    private fun addSpheresToScene___(positions: List<Vector3>, sphereRadius: Float = 0.1f) {
        // Forzar la limpieza de la ruta anterior si existe
        clearRouteNodes()

        // Lanzar una coroutine en el contexto del lifecycle
        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
            val modelNode = buildModelNode(R.raw.sphere, 0.05f) // Cargar el nodo una vez
            modelNode?.let {
                positions.forEach { position ->
                    Log.d(TAG, "> Situm add spheres to scene: $position")
                    val node: Node = Node(sceneView.engine).apply {
                        worldPosition = Position(position.x, position.y, position.z)
                        addChildNode(it)
                    }

                    routeNodes.add(node) // Agregar a la lista
                    // sceneView.addChildNode(node)
                }
                sceneView.addChildNodes(routeNodes) // Añadir todos los nodos a la escena
            }
        }
    }

    private fun addSpheresToScene_old(positions: List<Vector3>, sphereRadius: Float = 0.1f) {
        // force clear previous route if exists
        clearRouteNodes()

//        val material = MaterialLoader(sceneView.engine, context).createColorInstance(
//            Color(
//                0f, 0f, 1f, 0.5f
//            )
//        )
//        val sphereGeometry =
//            Sphere.Builder().radius(sphereRadius).center(Position(0f,0f,0f)).build(sceneView.engine)
        (activity as? LifecycleOwner)?.lifecycleScope?.launch {
            buildModelNode(R.raw.sphere, 0.05f)?.let {
                positions.forEach { position ->
                    Log.d(TAG, "> Situm add spheres to scene: $position")
                    val center = Position(position.x, position.y, position.z)
                    it.worldPosition = center
                    routeNodes.add(it)
                }

            }
        }
        sceneView.addChildNodes(routeNodes)
//        Log.d(TAG, "> Situm add spheres to scene")
//        positions.forEach { position ->
//            Log.d(TAG, "> Situm add spheres to scene: $position")
//            val center = Position(position.x, position.y, position.z)
//            val sphereNode = GeometryNode(sceneView.engine, sphereGeometry, material)
//            sphereNode.worldPosition = center
//            routeNodes.add(sphereNode)
//        }
//        sceneView.addChildNodes(routeNodes)
    }

    // from current AR position and AR RouteNodes, projects position on route and finds next node at n distance (?)
    private fun updateTargetArrowOnARRoute(minDistanceMeters: Float) {
        val cameraPosition = sceneView.cameraNode.worldPosition
        var closestNode: Node? = null
        var minDistanceToCamera = Float.MAX_VALUE

        //  Find closest node
        for (node in routeNodes) {
            Log.d(TAG, "> node: ${node.worldPosition} / ${node.position}")
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
        } else {
            Log.w(TAG, "< Closest node: ${closestNode.worldPosition}, ${closestNode.position}")
        }

        drawCurrentProjectedPosition(closestNode.worldPosition)
        var targetNode: Node? = null

        for (i in routeNodes.indexOf(closestNode) until routeNodes.size) {
            val node = routeNodes[i]
            val distanceFromClosest = calculate2DDistance(
                Vector3(
                    closestNode.worldPosition.x,
                    closestNode.worldPosition.y,
                    closestNode.worldPosition.z
                ), Vector3(node.worldPosition.x, node.worldPosition.y, node.worldPosition.z)
            )
            Log.d(
                TAG,
                "> Distance from closest: ${closestNode.worldPosition} to node: ${node.worldPosition}  : $distanceFromClosest "
            )
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
        if (::currentTargetNodeGeometry.isInitialized) {
            sceneView.removeChildNode(currentTargetNodeGeometry)
        }
        currentTargetNodeGeometry = drawSphereOnPosition(targetARPosition, Color(0f, 1f, 0f, 0.8f))
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

    //    // Función para dibujar el modelo con diferentes texturas
    fun drawDiskWithImage__new(arPosition: Position, poiCategory: PoiCategory) {
        // Verifica si el modelo ya fue cargado
//        if (diskModel == null) {
//            Log.e(TAG, ">> Disk model not loaded yet.")
//            return
//        }

        val texture = poisTexturesMap[poiCategory.identifier]
        sceneView.addChildNode(Node(sceneView.engine).apply {
            isEditable = true
            (activity as? LifecycleOwner)?.lifecycleScope?.launch {
                buildModelNode(R.raw.cilinder, 0.5f)?.let {
                    it.rotation = Rotation(-90f, 0f, 0f)
                    if (texture != null) {
                        val materialInstance =
                            MaterialLoader(sceneView.engine, context).createTextureInstance(
                                texture,
                                true
                            )

                        // Asignar el material clonado al modelo
                        //clonedDiskNode.modelInstance?.material = materialInstance
                        Log.e(TAG, ">> Set TEXTURE")
//                            it.modelInstance.materialInstances[0].setTexture("texture",texture)

                        it.modelInstance.materialInstances?.let { materialInstances ->
                            for (mi in materialInstances) {
                                Log.d(
                                    TAG,
                                    ">> mi: ${mi.name} / ${mi.material.name} / ${mi.material.parameterCount}"
                                )
                                for (i in 0 until mi.material.parameterCount) {
                                    Log.d(
                                        TAG,
                                        " >> mi.material.parameters[i].name: ${mi.material.parameters[i].name}"
                                    )
                                }
                                //mi.material.parameters.fin
                                //mi.material.setDefaultParameter("Texture",texture,TextureSampler())
                                // mi.setTexture(texture)
                                //mi.setParameter("tex-global", texture, TextureSampler())
//                                    for (i in 0 until mi.setParameter("texture",texture)) {
//                                        val paramName = mi.getParameterName(i)
//                                        Log.d(TAG, ">> Parameter: $paramName")
//                                    }
                                // mi.setParameter("texture",texture, TextureSampler())
//                                    try {
                                // mi.setTexture("tex-global",texture)
//                                    }catch (e:Exception){
//                                        Log.e(TAG,">> Exception $e")
//                                    }

//                                    mi.setTexture(texture)
                            }

                        }
//                                it.modelInstance?.asset?.let { asset ->
//                                    for (entity in asset.entities) {
////                                        // Verificamos si el entity tiene un material asociado
//                                        val material = sceneView.engine.renderableManager.getMaterialInstanceAt(entity, 0)
////                                        if (material != null) {
////                                            // Asignamos la nueva textura al material
////                                            material.setTexture("baseColorMap", texture)
////                                        }
//                                    }
//                                }
                    }


                    addChildNode(it)
                }
            }
            this.worldPosition = arPosition
            this.lookAt(sceneView.cameraNode)
            poiModelNode.add(this)
            // add to structyre

        })
//
//        val texture = poisTexturesMap[poiCategory.identifier]
//        if (texture != null) {
//            // Clonar el nodo del modelo cargado
//            val clonedDiskNode = diskModel?.modelInstance?.let { modelInstance ->
//                ModelNode(
//                    modelInstance = modelInstance,
//                ).apply {
//                    isEditable = true
//                    isVisible = true
//                }
//            }
//
//            if (clonedDiskNode != null) {
//                // Cargar el material con la textura
////                val materialInstance =
////                    MaterialLoader(sceneView.engine, context).createTextureInstance(texture, true)
////
////                // Asignar el material clonado al modelo
////                //clonedDiskNode.modelInstance?.material = materialInstance
////                clonedDiskNode.modelInstance?.asset?.let { asset ->
////                    for (entity in asset.entities) {
////                        // Verificamos si el entity tiene un material asociado
////                        val material = sceneView.engine.renderableManager.getMaterialInstanceAt(entity, 0)
////                        if (material != null) {
////                            // Asignamos la nueva textura al material
////                            material.setTexture("baseColorMap", texture)
////                        }
////                    }
////                }
////                // Ajustar la posición en AR
//                clonedDiskNode.worldPosition = arPosition
//                clonedDiskNode.lookAt(sceneView.cameraNode)
//
//                // Añadir el nodo clonado a la escena
//                sceneView.addChildNode(clonedDiskNode)
//
//                // Guardar el nodo si es necesario
//                poisDiskModelNodes.add(clonedDiskNode)
//
//                Log.d(TAG, ">> Disk node added to scene with texture. poisDiskModelNodes: ${poisDiskModelNodes.size}")
//            }
//        } else {
//            Log.e(TAG, ">> Failed to load texture.")
//        }
    }


    fun drawDiskWithImage(poiAR:PoiAR, arPosition: Position, poiCategory: PoiCategory) {

        if (poiAR.node!=null){
            poiAR.node?.worldPosition = arPosition
            return
        }

        val texture = poisTexturesMap[poiCategory.identifier]
        if (texture != null) {
            // Cargar el material con la textura
            val materialInstance =
                MaterialLoader(sceneView.engine, context).createTextureInstance(texture, true)
            // Crear el nodo con el disco (cilindro plano) y el material con la textura
            val diskGeometry2 = Cylinder.Builder().radius(0.5f).height(0.01f).build(sceneView.engine)

            val diskNode = GeometryNode(sceneView.engine, diskGeometry2, materialInstance)

            //diskNode.worldPosition = arPosition
            diskNode.rotation = Rotation(-90f, 0f, 0f)
            var node: Node = Node(sceneView.engine)
            node.addChildNode(diskNode)
            node.worldPosition = arPosition
            node.lookAt(sceneView.cameraNode)

            poiAR.geometryNode = diskNode
            poiAR.node = node
            //poisDiskNodes.add(diskNode)
            //poisNodes.add(node)

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

    private suspend fun loadPois() {
        if (::currentPosition.isInitialized && this.currentPosition != null && ::pois.isInitialized && pois.isNotEmpty()) {
            var nearPois = poiUtils.filterPoisByDistanceAndFloor(pois, currentPosition, 50)
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
                buildModelNode(R.raw.sphere_low, 0.5f)?.let { addChildNode(it) }
            }
            anchorNode = this
        })
    }


    private suspend fun buildModelNode(resId: Int, scale: Float): ModelNode? {
        return sceneView.modelLoader.loadModelInstance(activity.getResourceUri(resId))
            ?.let { modelInstance ->
                ModelNode(
                    modelInstance = modelInstance,
                    scaleToUnits = scale,
                    centerOrigin = Position(y = -0.5f)
                ).apply {}

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
        pois = emptyList()
        poisTexturesMap.clear()
    }

    fun clearAllNodes(node: Node) {
        node.childNodes.forEach { clearAllNodes(it) }  // Limpia recursivamente
        node.parent?.removeChildNode(node)           // Elimina el nodo del padre
        node.destroy()

    }

    private fun clearPoiNodes() {

        for (poi in poisAR.values){
            poi.node?.let { sceneView.removeChildNode(it) }
            poi.geometryNode?.let { sceneView.removeChildNode(it) }
            poi.clear()
        }
        poisAR.clear()
//        for (poiNode in poisTextNodes) {
//            clearAllNodes(poiNode)
//            //poiNode.parent = null
//        }

//        sceneView.removeChildNodes(poisTextNodes)
//        poisTextNodes.clear()
//
//        for (poiNode in poisDiskNodes) {
//            clearAllNodes(poiNode)
//            //poiNode.parent = null
//        }
//        sceneView.removeChildNodes(poisDiskNodes)
//        poisDiskNodes.clear()
//
//        for (poiNode in poiModelNode) {
//            clearAllNodes(poiNode)
//            poiNode.parent = null
//        }
//        sceneView.removeChildNodes(poiModelNode)
//        poiModelNode.clear()
//
//        for (poiNode in poisNodes) {
//            clearAllNodes(poiNode)
//            poiNode.parent = null
//        }
//        sceneView.removeChildNodes(poisNodes)
//        poisNodes.clear()
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

    override fun onStatusChanged(p0: LocationStatus) {

    }

    override fun onError(p0: Error) {

    }

    // callable from dart
    fun worldRedraw() {

        CoroutineScope(Dispatchers.IO).launch {
            loadPois()
//            updateRouteNodes()
//            updateTargetArrowOnARRoute(DIRECTION_ARROW_TARGET_DISTANCE)
        }
    }

    fun updateArrowTarget() {
        updateTargetArrowOnARRoute(DIRECTION_ARROW_TARGET_DISTANCE)
    }

    fun getCurrentStatusLog(): String {
        return arQuality.getCurrentStatusLog()
    }

}