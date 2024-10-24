package com.situm.flutter.ar.situm_ar.scene

import es.situm.sdk.model.cartography.Poi
import es.situm.sdk.model.cartography.Point
import es.situm.sdk.model.location.Location
import io.github.sceneview.node.GeometryNode
import io.github.sceneview.node.Node
import io.github.sceneview.node.ViewNode
import kotlin.math.pow
import kotlin.math.sqrt

data class PoiAR(
    val poi: Poi,
    var viewNode: ViewNode? = null, // TextView
    var geometryNode: GeometryNode? = null, // disk
    var node: Node? = null
) {
    fun clear() {
//        viewNode?.clearChildNodes()
//        viewNode?.destroy()

//        geometryNode?.destroy()
        geometryNode?.clearChildNodes()
        geometryNode?.parent = null
        geometryNode = null


        node?.clearChildNodes()
        node?.parent = null
//        node?.destroy()
        node = null


    }
}


class PoiUtils{


    fun filterPoisByDistanceAndFloor(
        pois: List<Poi>,
        location: Location,
        maxDistance: Int
    ): List<Poi> {
        return pois.filter { poi ->
            // Verificar si el Poi está en el mismo piso
            val sameFloor = poi.buildingIdentifier == location.buildingIdentifier &&
                    poi.position.floorIdentifier == location.floorIdentifier

            if (sameFloor) {
                // Calcular la distancia entre la ubicación y el Poi
                val distance = calculateDistance(location, poi.position)

                // Verificar si la distancia es menor que la distancia máxima
                return@filter distance < maxDistance
            }

            return@filter false
        }
    }

    fun calculateDistance(location1: Location, point: Point): Double {
        val x1 = location1.cartesianCoordinate.x
        val y1 = location1.cartesianCoordinate.y
        val x2 = point.cartesianCoordinate.x
        val y2 = point.cartesianCoordinate.y

        // Fórmula para calcular la distancia euclidiana entre dos puntos
        return sqrt((x2 - x1).pow(2) + (y2 - y1).pow(2))
    }

    fun calculateRelativePosition(currentLocation: Location, poi: Poi): RelativePosition {
        val relativeX = poi.position.cartesianCoordinate.x - currentLocation.cartesianCoordinate.x
        val relativeY = poi.position.cartesianCoordinate.y - currentLocation.cartesianCoordinate.y

        // TODO: Calculate bearing

        return RelativePosition(relativeX = relativeX, relativeY = relativeY)
    }

    fun calculateRelativePositions(currentLocation: Location, nearPois: List<Poi>): List<RelativePosition> {
        return nearPois.map { poi ->
            calculateRelativePosition(currentLocation, poi)
        }
    }


    fun getPoiNodeFromId(pois: List<Poi>, poiNodes: List<ViewNode>, poiId: String): ViewNode? {
        // Asegurarse de que las dos listas tengan el mismo tamaño
        if (pois.size != poiNodes.size) {
            throw IllegalArgumentException("Las listas de POIs y ViewNodes deben tener el mismo tamaño.")
        }

        // Recorrer ambas listas al mismo tiempo
        for (i in pois.indices) {
            if (pois[i].identifier == poiId) { // Suponemos que el POI tiene un campo `id`
                return poiNodes[i] // Devolver el ViewNode correspondiente
            }
        }

        // Si no se encuentra el POI con ese ID, devolver null
        return null
    }



}
