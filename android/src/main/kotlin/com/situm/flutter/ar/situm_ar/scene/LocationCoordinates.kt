package com.situm.flutter.ar.situm_ar.scene

import kotlin.math.absoluteValue
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt


data class LocationCoordinates(
    val x: Double,
    val y: Double,
    val yaw: Double,
    val timestamp: Long,
    val floorIdentifier: String = "",
    val accuracy : Long =0,
    val hasBearing : Boolean = true,
) {

    operator fun minus(other: LocationCoordinates): LocationCoordinates {
        return LocationCoordinates(
            x - other.x,
            y - other.y,
            yawAdd(-other.yaw),
            timestamp - other.timestamp,
            floorIdentifier
        )
    }

    fun distanceTo(other: LocationCoordinates): Double {
        return sqrt((x - other.x).pow(2) + (y - other.y).pow(2))
    }

    fun rotate(angle: Double): LocationCoordinates {
        val cosA = cos(angle)
        val sinA = sin(angle)
        return LocationCoordinates(
            x * cosA - y * sinA,
            x * sinA + y * cosA,
            yawAdd(angle),
            timestamp,
            floorIdentifier
        )
    }

    fun angularDistanceTo(other: LocationCoordinates): Double {
        var angleDifference = yaw - other.yaw
        angleDifference = normalizeAngle(angleDifference)
        return angleDifference.absoluteValue
    }

    fun yawAdd(angle: Double): Double {
        var sum = yaw + angle
        sum = normalizeAngle(sum)
        return sum
    }

    private fun normalizeAngle(angle: Double): Double {
        var normalizedAngle = angle % (2 * Math.PI)
        if (normalizedAngle < -Math.PI) {
            normalizedAngle += 2 * Math.PI
        } else if (normalizedAngle > Math.PI) {
            normalizedAngle -= 2 * Math.PI
        }
        return normalizedAngle
    }

    override fun toString(): String {
        return "LocationCoordinates(x: $x, y: $y, yaw: $yaw, timestamp: $timestamp)"
    }
}