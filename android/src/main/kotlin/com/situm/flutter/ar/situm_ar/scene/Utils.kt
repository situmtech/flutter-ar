package com.situm.flutter.ar.situm_ar.scene

import io.github.sceneview.collision.Vector3

data class RelativePosition(
    val relativeX: Double,
    val relativeY: Double
) {
    override fun toString(): String {
        return "RelativePosition(relativeX=$relativeX, relativeY=$relativeY)"
    }
}

fun interpolatePositions(positions: List<Vector3>, distanceBetweenPoints: Float = 1.0f): List<Vector3> {
    val interpolatedPositions = mutableListOf<Vector3>()

    for (i in 0 until positions.size - 1) {
        val start = positions[i]
        val end = positions[i + 1]

        // Add the starting point
        interpolatedPositions.add(start)

        // Calculate the distance between the current point and the next
        val distance = calculateDistance(start, end)

        // Calculate how many new points we need to add
        val numNewPoints = (distance / distanceBetweenPoints).toInt()

        // Calculate the direction vector (normalized)
        val direction = Vector3(
            (end.x - start.x) / distance,
            (end.y - start.y) / distance,
            (end.z - start.z) / distance
        )

        // Add interpolated points
        for (j in 1..numNewPoints) {
            val interpolatedPoint = Vector3(
                start.x + direction.x * j * distanceBetweenPoints,
                start.y + direction.y * j * distanceBetweenPoints,
                start.z + direction.z * j * distanceBetweenPoints
            )
            interpolatedPositions.add(interpolatedPoint)
        }
    }

    // Add the last point from the original list
    interpolatedPositions.add(positions.last())

    return interpolatedPositions
}

fun calculateDistance(start: Vector3, end: Vector3): Float {
    return Math.sqrt(
        ((end.x - start.x) * (end.x - start.x) +
                (end.y - start.y) * (end.y - start.y) +
                (end.z - start.z) * (end.z - start.z)).toDouble()
    ).toFloat()
}

fun calculate2DDistance(start: Vector3, end: Vector3): Float {
    return Math.sqrt(
        ((end.x - start.x) * (end.x - start.x) +
                (end.z - start.z) * (end.z - start.z)).toDouble()
    ).toFloat()
}

