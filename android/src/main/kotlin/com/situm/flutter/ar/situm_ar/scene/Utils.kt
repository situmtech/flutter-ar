package com.situm.flutter.ar.situm_ar.scene

import android.util.Log
import io.github.sceneview.collision.Vector3
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random
import kotlin.system.measureTimeMillis

const val TAG = "Situm> AR>"

fun interpolatePositions(
    positions: List<Vector3>,
    distanceBetweenPoints: Float = 1.0f
): MutableList<Vector3> {
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
    return sqrt(
        ((end.x - start.x) * (end.x - start.x) +
                (end.y - start.y) * (end.y - start.y) +
                (end.z - start.z) * (end.z - start.z)).toDouble()
    ).toFloat()
}

fun multiplyVectorScalar(vector: Vector3, scalar: Float): Vector3 {
    return Vector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
}


fun addVectors(vector1: Vector3, vector2: Vector3): Vector3 {
    return Vector3(vector1.x + vector2.x, vector1.y + vector2.y, vector1.z + vector2.z)
}

fun calculate2DDistance(start: Vector3, end: Vector3): Float {
    return sqrt(
        ((end.x - start.x) * (end.x - start.x) +
                (end.z - start.z) * (end.z - start.z)).toDouble()
    ).toFloat()
}

fun isPositionValid(
    newPosition: Position,
    existingPositions: List<Position>,
    minDistance: Float
): Boolean {
    return existingPositions.all { existingPosition ->
        distanceBetween(newPosition, existingPosition) > minDistance
    }
}

fun distanceBetween(pos1: Position, pos2: Position): Double {
    val dx = pos1.x - pos2.x
    val dz = pos1.z - pos2.z
    return sqrt((dx * dx + dz * dz).toDouble())
}

inline fun logExecutionTime(tag: String = "ExecutionTime", block: () -> Unit) {
    val time = measureTimeMillis {
        block()
    }
    Log.d(tag, "Execution Time: $time ms")
}

fun getVisibleModelPositions(fenceModels: Map<String, SitumARModel>): List<Position> {
    return fenceModels.values
        .filter { it.modelNode.isVisible } // Filter visible nodes
        .map { it.modelNode.worldPosition } // Get positions
}


fun generateValidPosition(
    cameraPosition: Position,
    cameraRotation: Rotation,
    maxDistance: Float,
    heightOffset: Float,
    coneAngle: Float,
    existingPositions: List<Position>,
    minDistance: Float,
    maxRetries: Int = 10
): Position? {
    repeat(maxRetries) {
        val newPosition = getRandomPositionInViewCone(
            cameraPosition,
            cameraRotation,
            maxDistance,
            heightOffset,
            coneAngle
        )
        if (isPositionValid(newPosition, existingPositions, minDistance)) {
            return newPosition
        }
    }
    Log.w(TAG, "Could not generate a valid position after $maxRetries attempts.")
    return null
}

fun toRadians(degrees: Double): Double {
    return degrees * (PI / 180)
}

fun getRandomPositionInViewCone(
    cameraPosition: Position,
    cameraWorldRotation: Rotation,
    maxDistance: Float,
    fixedHeight: Float,
    coneAngle: Float = 70f
): Position {

    val rotationYRadians = toRadians(cameraWorldRotation.y.toDouble()) - PI / 2
    val randomAngle = (Random.nextFloat() * coneAngle - coneAngle / 2)
    val angleRad = toRadians(randomAngle.toDouble())

    val minDistance = 2f
    val distance = Random.nextFloat() * maxDistance + minDistance

    val offsetX =
        distance * (cos(angleRad) * cos(rotationYRadians) - sin(angleRad) * sin(
            rotationYRadians
        ))
    val offsetZ =
        distance * (sin(angleRad) * cos(rotationYRadians) + cos(angleRad) * sin(
            rotationYRadians
        ))

    return Position(
        x = (cameraPosition.x + offsetX).toFloat(),
        y = fixedHeight,
        z = (cameraPosition.z + offsetZ).toFloat()
    )
}