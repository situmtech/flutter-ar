package com.situm.flutter.ar.situm_ar.scene

import android.app.Activity
import android.content.Context
import android.util.Log
import com.situm.flutter.ar.situm_ar.scene.ARSceneHandler.Companion
import es.situm.sdk.SitumSdk
import es.situm.sdk.model.directions.Route
import es.situm.sdk.model.directions.RouteSegment
import es.situm.sdk.model.location.Location
import es.situm.sdk.model.navigation.NavigationProgress
import es.situm.sdk.navigation.NavigationListener
import io.github.sceneview.SceneView
import io.github.sceneview.collision.Vector3
import io.github.sceneview.geometries.Sphere
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.math.Color
import io.github.sceneview.math.Position
import io.github.sceneview.node.GeometryNode
import io.github.sceneview.node.ModelNode
import io.github.sceneview.node.Node

class RouteARManager(private val context: Context,
                     private val sceneView: SceneView,
                     private val activity: Activity,
                     private val onDebug: Boolean = false): NavigationListener {

    internal lateinit var currentPosition: Location
    private lateinit var currentSegment: RouteSegment
    private var routePointsAR: MutableList<Vector3> = mutableListOf()
    private lateinit var route: Route

    internal var arrowNode: ModelNode? = null
    internal var targetArrow: Position? = null

    private val routeNodes: MutableList<Node> = mutableListOf()     // only for debug
    private var hasToShowDebugRoute: Boolean = false

    // Navigation listener
    override fun onStart(route: Route) {        // This may not be called
        Log.w(ARSceneHandler.TAG, ">>>>> on start navigation listener")
        setRoute(route)
        updateRouteNodes()
        updateArrowTarget()
    }

    override fun onProgress(navigationProgress: NavigationProgress?) {
        Log.w(ARSceneHandler.TAG, ">> Situm navigation progress: ${navigationProgress.toString()}")

        navigationProgress?.segments?.get(0)?.let { setCurrentSegment(it) }
        if (hasToUpdateArrowTarget()) {
            updateArrowTarget()
        }
        return
    }

    override fun onUserOutsideRoute() {
        Log.w(ARSceneHandler.TAG, ">> Situm navigation user out of routes")
    }


    override fun onCancellation() {
        Log.w(ARSceneHandler.TAG, ">> Situm navigation onCancellation")
        makeRouteInvisible()
        super.onCancellation()
    }

    override fun onDestinationReached(route: Route?) {
        Log.w(ARSceneHandler.TAG, ">> Situm navigation on destination reached")
        makeRouteInvisible()
        sendArGoneCallback?.onARGoneRequired()
        super.onDestinationReached(route)
    }


    private fun setRoute(route: Route) {
        this.route = route
    }
    private fun setCurrentSegment(routeSegment: RouteSegment) {
        this.currentSegment = routeSegment
    }

    internal fun updateRouteNodes() {
        if (!this::currentSegment.isInitialized || !this::currentPosition.isInitialized) {
            return
        }
        currentSegment.points.let { nonNullRoute ->
            val arCorePositionsForPoints = generateARCorePositions(
                nonNullRoute, currentPosition, sceneView.cameraNode
            ) { point -> point.cartesianCoordinate }

            routePointsAR = interpolatePositions(arCorePositionsForPoints, 1.0f)
            if (hasToShowDebugRoute) {
                addSpheresToScene(routePointsAR)
            }
        }
    }
    fun updateArrowTarget() {
        updateTargetArrowOnARRoute(DIRECTION_ARROW_TARGET_DISTANCE)
    }
    internal fun updateTargetArrowOnARRoute(minDistanceMeters: Float) {
        val cameraPosition = sceneView.cameraNode.worldPosition
        var closestPoint: Vector3? = null
        var targetPoint: Vector3? = null
        var minDistanceToCamera = Float.MAX_VALUE

        Log.d(Companion.TAG, ">> updateTargetArrowOnARRoute  ")
        //  Find closest node
        for (point in routePointsAR) {
            Log.d(Companion.TAG, "> route point: $point ")
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
            Log.w(Companion.TAG, "> No closest node found.")
            return
        } else {
            Log.w(Companion.TAG, "< Closest node: $closestPoint")
        }

        for (i in routePointsAR.indexOf(closestPoint) until routePointsAR.size) {
            val position = routePointsAR[i]
            val distanceFromClosest = calculate2DDistance(closestPoint, position)
            Log.d(
                Companion.TAG,
                ">> Distance from closest: $closestPoint to node: $position  : $distanceFromClosest "
            )
            if (distanceFromClosest >= minDistanceMeters) {
                targetPoint = position
                break
            }
        }
        if (targetPoint != null) {
            Log.d(Companion.TAG, "> Target node found at position: $targetPoint")
            pointArrowToPosition(Position(targetPoint.x, targetPoint.y, targetPoint.z))
        } else {
            Log.w(
                Companion.TAG,
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

    internal fun makeRouteInvisible() {
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
            routeNodes[i].apply {
                worldPosition = Position(positions[i].x, positions[i].y, positions[i].z)
                isVisible = true
            }
        }
    }


    fun switchShowRouteOnAR() {
        hasToShowDebugRoute = !hasToShowDebugRoute
        if (!hasToShowDebugRoute) {
            makeRouteInvisible()
        }
        Log.d(Companion.TAG, ">> hasToShowRoute: $hasToShowDebugRoute")
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
    fun stop() {
        makeRouteInvisible()
        clearRouteNodes()
    }

    private var sendArGoneCallback: ARSceneHandlerCallback? = null

    fun setARGoneCallback(callback: ARSceneHandlerCallback) {
        this.sendArGoneCallback = callback
    }

}