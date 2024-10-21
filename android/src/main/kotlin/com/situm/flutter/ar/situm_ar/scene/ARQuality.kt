package com.situm.flutter.ar.situm_ar.scene

import dev.romainguy.kotlin.math.pow
import es.situm.sdk.model.location.Location
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt


const val BUFFER_SIZE = 15

const val DEFAULT_REFRESH_THRESHOLD = 0.2
const val CONSTANT_QUALITY_DECREASE_RATE = 0.005        // Every iteration always decreases this
const val QUALITY_THRESHOLD_DECREASE_RATE = 0.03        // when low quality, threshold decreases faster

data class RefreshThreshold(var value: Double, var timestamp: Long) {
    override fun toString(): String {
        return "RefreshThreshold(value: $value, timestamp: $timestamp)"
    }
}


class ARQuality {

    private var currentRefreshThreshold: RefreshThreshold = RefreshThreshold(0.2,0)
    private var dynamicRefreshThreshold: RefreshThreshold = RefreshThreshold(0.2,0)

    private var quality: Double = 0.0

    private var odometriesDistanceConf: Double = 0.0
    private var situmConf: Double = 0.0
    private var arConf: Double= 0.0
    private var arDisplacementConf: Double= 0.0
    private var situmDisplacementConf: Double = 0.0

    private var arLocationBuffer: MutableList<LocationCoordinates> = mutableListOf()
    private var situmLocationBuffer: MutableList<LocationCoordinates> = mutableListOf()


    fun updateARLocation(worldPosition: Position, worldRotation: Rotation) {
        arLocationBuffer.add(LocationCoordinates(worldPosition.x.toDouble(),
            worldPosition.z.toDouble(), worldRotation.y.toDouble(), System.currentTimeMillis()))  //TODO: Check rotation
        if (arLocationBuffer.size> BUFFER_SIZE){
            arLocationBuffer.removeAt(0)
        }
    }

    fun updateSitumLocation(location: Location){
        if (situmLocationBuffer.isNotEmpty() && situmLocationBuffer.last().floorIdentifier != location.floorIdentifier){
            situmLocationBuffer.clear()
            arLocationBuffer.clear()
            resetThreshold()
        }
        situmLocationBuffer.add(LocationCoordinates(location.cartesianCoordinate.x, location.cartesianCoordinate.y,location.cartesianBearing.degrees(),System.currentTimeMillis(),location.floorIdentifier,
            location.accuracy.toLong(), location.hasBearing() ))
        if (situmLocationBuffer.size> BUFFER_SIZE){
            situmLocationBuffer.removeAt(0)
        }
    }


    fun hasToResetWorld():Boolean{
        updateConfidence()
        return checkIfHasToRefreshAndUpdateThreshold(quality,arConf, situmConf)
    }
    fun updateConfidence() {
        if (situmLocationBuffer.isEmpty() || arLocationBuffer.isEmpty()){
            arConf = 0.0
            situmConf = 0.0
            quality = 0.0
            return
        }
        val  totalDisplacementSitum = computeTotalDisplacement(situmLocationBuffer)
        val  totalDisplacementAR = computeTotalDisplacement(arLocationBuffer)

        val odometriesDistance = estimateOdometriesMatch(arLocationBuffer, situmLocationBuffer)

        situmDisplacementConf = totalDisplacementConf(totalDisplacementSitum)
        arDisplacementConf = totalDisplacementConf(totalDisplacementAR)
        arConf = estimateArConf()
        situmConf = estimateSitumConf()
        odometriesDistanceConf = odometriesDifferenceConf(odometriesDistance)

        quality = situmDisplacementConf * arDisplacementConf * arConf * situmConf * odometriesDistanceConf
    }


    private fun estimateOdometriesMatch(arLocationBuffer: MutableList<LocationCoordinates>, situmLocationBuffer: MutableList<LocationCoordinates>): Double {
        var transformedARTrajectory = transformTrajectory(arLocationBuffer)
        var transformedSitumTrajectory = transformTrajectory(situmLocationBuffer)
        val distance = transformedARTrajectory.last().distanceTo(transformedSitumTrajectory.last())

        return distance;

    }

    fun transformTrajectory(arLocationBuffer: MutableList<LocationCoordinates>): List<LocationCoordinates> {
        if (arLocationBuffer.isEmpty()) return emptyList()

        // Translate to origin
        val origin = arLocationBuffer[0]
        val translatedTrajectory = arLocationBuffer.map { loc -> loc - origin }
        if (translatedTrajectory.size == 1) return translatedTrajectory

        // Find a miminum displacement
        var distance = 0.0
        var index = 1
        while (index < translatedTrajectory.size) {
            distance = translatedTrajectory[0].distanceTo(translatedTrajectory[index])
            if (distance > 2) break
            index++
        }
        if (index >= translatedTrajectory.size) {
            return translatedTrajectory
        }

        // Calculate rotation
        val firstVector = translatedTrajectory[index]
        val angle = atan2(firstVector.y, firstVector.x)

        // Apply rotation
        val alignedTrajectory = translatedTrajectory.map { loc -> loc.rotate(-angle) }

        return alignedTrajectory
    }


    fun computeTotalDisplacement(coordinates: List<LocationCoordinates>): Double {
        if (coordinates.size < 2) return 0.0
        return coordinates.first().distanceTo(coordinates.last())
    }


    fun estimateArConf(): Double {
        val requiredPositions = 10
        val maxConfidence = 1.0
        var numOkPositions = 0

        // Ckeck last 10 positions
        var confidence = maxConfidence
        for (i in arLocationBuffer.size - 1 downTo maxOf(arLocationBuffer.size - requiredPositions, 0)) {
            // Si no hay AR, se congela, recibimos el último valor nuevamente.      // TODO: Chek if this continues to be true with the new library
            if ((arLocationBuffer[i].x == 0.0 && arLocationBuffer[i].y == 0.0) ||
                i < 1 ||
                (arLocationBuffer[i].y == arLocationBuffer[i - 1].y && arLocationBuffer[i].x == arLocationBuffer[i - 1].x)
            ) {
                break
            } else {
                numOkPositions++
            }
        }
        confidence = (numOkPositions.toDouble() / requiredPositions) * maxConfidence
        return confidence
    }


    fun estimateSitumConf(): Double {
        val requiredPositions = 10
        val maxConfidence = 1.0
        var numOkPositions = 0
        var confidence = maxConfidence

        for (i in situmLocationBuffer.size - 1 downTo maxOf(situmLocationBuffer.size - requiredPositions, 0)) {
            if ((situmLocationBuffer[i].accuracy > 5 && !situmLocationBuffer[i].hasBearing) || i < 0) {
                break
            } else {
                numOkPositions++
            }
        }

        confidence = (numOkPositions.toDouble() / requiredPositions) * maxConfidence
        return confidence
    }

    fun totalDisplacementConf(distance: Double): Double {
        val minDistanceThreshold = 10.0
        return if (distance > minDistanceThreshold) {
            1.0
        } else {
            distance / minDistanceThreshold
        }
    }
    fun odometriesDifferenceConf(difference: Double): Double {
        val diffThreshold = 10.0
        return if (difference > diffThreshold) {
            0.0
        } else {
            1.0 - difference / diffThreshold
        }
    }

    fun checkIfHasToRefreshAndUpdateThreshold(conf: Double, arConf: Double, situmConf: Double): Boolean {
        val currentTimestamp = System.currentTimeMillis()

        // Si la confianza de AR o Situm es menor que 0.8, reiniciar el umbral y devolver true
        if (arConf < 0.8 || situmConf < 0.8) {
            resetThreshold()
            return true
        }

        // Reducir siempre el umbral si es necesario
        if (currentRefreshThreshold.value > 0.20 &&
            currentTimestamp - currentRefreshThreshold.timestamp > 1000) {
            currentRefreshThreshold.value = currentRefreshThreshold.value - CONSTANT_QUALITY_DECREASE_RATE
        }

        // Si la confianza es mayor que el umbral actual + 0.2, actualizar el umbral y devolver true
        if (conf > currentRefreshThreshold.value + 0.2) {
            currentRefreshThreshold.value = conf
            currentRefreshThreshold.timestamp = currentTimestamp
            dynamicRefreshThreshold = currentRefreshThreshold
            return true
        }
        // Si la confianza es menor que el umbral actual y ha pasado más de 1 segundo, disminuir el umbral
        else if (conf < currentRefreshThreshold.value &&
            currentTimestamp - currentRefreshThreshold.timestamp > 1000 &&
            currentRefreshThreshold.value > 0.20) {
            currentRefreshThreshold.value = currentRefreshThreshold.value - QUALITY_THRESHOLD_DECREASE_RATE
            currentRefreshThreshold.timestamp = currentTimestamp
            dynamicRefreshThreshold = currentRefreshThreshold
            return false
        }
        // Si ha pasado más de 30 segundos, actualizar el umbral con el valor de confianza o 0.2
        else if (currentTimestamp - currentRefreshThreshold.timestamp > 30000) {
            currentRefreshThreshold.value = if (conf > 0.2) conf else 0.2
            currentRefreshThreshold.timestamp = currentTimestamp
            dynamicRefreshThreshold = currentRefreshThreshold
            return true
        }

        return false
    }

    private fun resetThreshold() {
        currentRefreshThreshold.timestamp = System.currentTimeMillis()
        currentRefreshThreshold.value = DEFAULT_REFRESH_THRESHOLD
        dynamicRefreshThreshold = currentRefreshThreshold

    }


}