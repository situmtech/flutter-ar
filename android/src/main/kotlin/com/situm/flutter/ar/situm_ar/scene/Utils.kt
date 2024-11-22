package com.situm.flutter.ar.situm_ar.scene

import android.util.Log
import io.github.sceneview.collision.Vector3
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import kotlin.random.Random
import kotlin.system.measureTimeMillis

data class RelativePosition(
    val relativeX: Double,
    val relativeY: Double
) {
    override fun toString(): String {
        return "RelativePosition(relativeX=$relativeX, relativeY=$relativeY)"
    }
}

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
    return Math.sqrt(
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
    return Math.sqrt(
        ((end.x - start.x) * (end.x - start.x) +
                (end.z - start.z) * (end.z - start.z)).toDouble()
    ).toFloat()
}

inline fun logExecutionTime(tag: String = "ExecutionTime", block: () -> Unit) {
    val time = measureTimeMillis {
        block()
    }
    Log.d(tag, "Tiempo de ejecución: $time ms")
}

fun getRandomPositionNearPosition(
    cameraPosition: Position,
    maxDistance: Float,
    heightOffset: Float
): Position {
    // Genera desplazamientos aleatorios en los ejes X, Y y Z
    val randomOffsetX = Random.nextFloat() * maxDistance * 2 - maxDistance
    val randomOffsetZ = Random.nextFloat() * maxDistance * 2 - maxDistance

    // Suma los desplazamientos aleatorios a la posición de la cámara
    return Position(
        cameraPosition.x + randomOffsetX,
        cameraPosition.y + heightOffset,
        cameraPosition.z + randomOffsetZ
    )
}


fun getRandomPositionInViewCone(
    cameraPosition: Position,
    cameraDirection: Rotation,
    maxDistance: Float,
    heightOffset: Float,
    coneAngle: Float = 70f
): Position {
    // Genera un ángulo aleatorio dentro del rango ±coneAngle
    val randomAngle = Random.nextFloat() * 2 * coneAngle - coneAngle

    // Convierte el ángulo a radianes
    val angleRad = Math.toRadians(randomAngle.toDouble())

    // Genera una distancia aleatoria hacia adelante dentro del rango [0, maxDistance]
    val distance = Random.nextFloat() * maxDistance

    // Calcula las direcciones de desplazamiento en el plano XZ
    val offsetX = distance * Math.cos(angleRad)
    val offsetZ = distance * Math.sin(angleRad)

    // Usa la dirección de la cámara para orientar los desplazamientos
    val forwardX = cameraDirection.x
    val forwardZ = -cameraDirection.z
    val length = Math.sqrt((forwardX * forwardX + forwardZ * forwardZ).toDouble()) // Normalizar

    // Evita división por cero al normalizar
    val normalizedX = if(length > 1e-6) forwardX / length else 0f
    val normalizedZ = if (length > 1e-6) forwardZ / length else 0f

    // Proyecta la posición final en el cono de visión

    val finalX = cameraPosition.x + (normalizedX.toFloat() * offsetX - normalizedZ.toFloat() * offsetZ).toFloat()
    val finalZ = cameraPosition.z + (normalizedZ.toFloat() * offsetX + normalizedX.toFloat() * offsetZ).toFloat()

    return Position(
        x = finalX,
        y = cameraPosition.y + heightOffset,
        z = finalZ
    )
}
