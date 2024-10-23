import Foundation
import SceneKit
import CoreLocation
import SitumSDK

let BUFFER_SIZE = 15

struct RefreshThreshold {
    var value: Double
    var timestamp: TimeInterval

    func description() -> String {
        return "RefreshThreshold(value: \(value), timestamp: \(timestamp))"
    }
}

class ARQuality {

    private var currentRefreshThreshold = RefreshThreshold(value: 0.2, timestamp: 0)
    private var dynamicRefreshThreshold = RefreshThreshold(value: 0.2, timestamp: 0)

    private var quality: Double = 0.0

    private var odometriesDistanceConf: Double = 0.0
    private var situmConf: Double = 0.0
    private var arConf: Double = 0.0
    private var arDisplacementConf: Double = 0.0
    private var situmDisplacementConf: Double = 0.0

    private var arLocationBuffer: [LocationCoordinates] = []
    private var situmLocationBuffer: [LocationCoordinates] = []
    
    var CONSTANT_QUALITY_DECREASE_RATE = 0.005
    var QUALITY_THRESHOLD_DECREASE_RATE = 0.03

    func updateARLocation(worldPosition: SCNVector3, worldRotation: SCNQuaternion) {
        let currentTime = Date().timeIntervalSince1970 * 1000 // Esto ya es Double (TimeInterval)
        
        arLocationBuffer.append(LocationCoordinates(x: Double(worldPosition.x),
                                                    y: Double(worldPosition.z),
                                                    yaw: Double(worldRotation.y),
                                                    timestamp: currentTime)) // currentTime ya es TimeInterval

        if arLocationBuffer.count > BUFFER_SIZE {
            arLocationBuffer.removeFirst()
        }
    }

    func setQualityDecrease(qualityDecrease: Float){
        self.CONSTANT_QUALITY_DECREASE_RATE = Double(qualityDecrease)        
    }
    func setThresholdDecrease(thresholdDecrease: Float){
        self.QUALITY_THRESHOLD_DECREASE_RATE = Double(thresholdDecrease)
    }


    func updateSitumLocation(location: SITLocation) {
        if !situmLocationBuffer.isEmpty, situmLocationBuffer.last?.floorIdentifier != location.position.floorIdentifier {
            situmLocationBuffer.removeAll()
            arLocationBuffer.removeAll()
            // TODO: RESET Threshold
        }
        
        // Desempaquetar de forma segura los valores opcionales
        if let cartesianCoordinate = location.position.cartesianCoordinate {
            let currentTime = Date().timeIntervalSince1970 * 1000
            
            situmLocationBuffer.append(LocationCoordinates(
                x: Double(cartesianCoordinate.x),
                y: Double(cartesianCoordinate.y),
                yaw: Double(location.cartesianBearing.degrees()),
                timestamp: currentTime,
                floorIdentifier: location.position.floorIdentifier ?? "",
                accuracy: Int64(location.accuracy),
                hasBearing: location.hasBearing()
            ))
            
            if situmLocationBuffer.count > BUFFER_SIZE {
                situmLocationBuffer.removeFirst()
            }
        } else {
            print("Error: cartesianCoordinate es nil")
        }
    }


    func hasToResetWorld() -> Bool {
        updateConfidence()
        return checkIfHasToRefreshAndUpdateThreshold(conf: quality, arConf: arConf, situmConf: situmConf)
    }

    func updateConfidence() {
        guard !situmLocationBuffer.isEmpty, !arLocationBuffer.isEmpty else {
            arConf = 0.0
            situmConf = 0.0
            quality = 0.0
            return
        }

        let totalDisplacementSitum = computeTotalDisplacement(coordinates: situmLocationBuffer)
        let totalDisplacementAR = computeTotalDisplacement(coordinates: arLocationBuffer)
        let odometriesDistance = estimateOdometriesMatch(arLocationBuffer: arLocationBuffer, situmLocationBuffer: situmLocationBuffer)

        situmDisplacementConf = totalDisplacementConf(distance: totalDisplacementSitum)
        arDisplacementConf = totalDisplacementConf(distance: totalDisplacementAR)
        arConf = estimateArConf()
        situmConf = estimateSitumConf()
        odometriesDistanceConf = odometriesDifferenceConf(difference: odometriesDistance)

        quality = situmDisplacementConf * arDisplacementConf * arConf * situmConf * odometriesDistanceConf
    }

    private func estimateOdometriesMatch(arLocationBuffer: [LocationCoordinates], situmLocationBuffer: [LocationCoordinates]) -> Double {
        let transformedARTrajectory = transformTrajectory(trajectory: arLocationBuffer)
        let transformedSitumTrajectory = transformTrajectory(trajectory: situmLocationBuffer)
        
        // Llamada a distanceTo sin el label `other`
        return transformedARTrajectory.last!.distanceTo(transformedSitumTrajectory.last!)
    }


    func transformTrajectory(trajectory: [LocationCoordinates]) -> [LocationCoordinates] {
        guard !trajectory.isEmpty else { return [] }

        // Translate to origin
        let origin = trajectory[0]
        let translatedTrajectory = trajectory.map { $0 - origin }
        if translatedTrajectory.count == 1 { return translatedTrajectory }

        // Find minimum displacement
        var distance = 0.0
        var index = 1
        while index < translatedTrajectory.count {
            // Llamada sin 'other:'
            distance = translatedTrajectory[0].distanceTo(translatedTrajectory[index])
            if distance > 2 { break }
            index += 1
        }

        guard index < translatedTrajectory.count else { return translatedTrajectory }

        // Calculate rotation
        let firstVector = translatedTrajectory[index]
        let angle = atan2(firstVector.y, firstVector.x)

        // Apply rotation con el label correcto 'by'
        let alignedTrajectory = translatedTrajectory.map { $0.rotate(by: -angle) }

        return alignedTrajectory
    }


    func computeTotalDisplacement(coordinates: [LocationCoordinates]) -> Double {
        guard coordinates.count >= 2 else { return 0.0 }
        return coordinates.first!.distanceTo(coordinates.last!)
    }


    func estimateArConf() -> Double {
        let requiredPositions = 10
        let maxConfidence = 1.0
        var numOkPositions = 0

        var confidence = maxConfidence
        for i in stride(from: arLocationBuffer.count - 1, through: max(arLocationBuffer.count - requiredPositions, 0), by: -1) {
            if (arLocationBuffer[i].x == 0.0 && arLocationBuffer[i].y == 0.0) ||
                i < 1 ||
                (arLocationBuffer[i].y == arLocationBuffer[i - 1].y && arLocationBuffer[i].x == arLocationBuffer[i - 1].x) {
                break
            } else {
                numOkPositions += 1
            }
        }
        confidence = (Double(numOkPositions) / Double(requiredPositions)) * maxConfidence
        return confidence
    }

    func estimateSitumConf() -> Double {
        let requiredPositions = 10
        let maxConfidence = 1.0
        var numOkPositions = 0

        var confidence = maxConfidence
        for i in stride(from: situmLocationBuffer.count - 1, through: max(situmLocationBuffer.count - requiredPositions, 0), by: -1) {
            if situmLocationBuffer[i].accuracy > 5 && !situmLocationBuffer[i].hasBearing || i < 0 {
                break
            } else {
                numOkPositions += 1
            }
        }
        confidence = (Double(numOkPositions) / Double(requiredPositions)) * maxConfidence
        return confidence
    }

    func totalDisplacementConf(distance: Double) -> Double {
        let minDistanceThreshold = 10.0
        return distance > minDistanceThreshold ? 1.0 : distance / minDistanceThreshold
    }

    func odometriesDifferenceConf(difference: Double) -> Double {
        let diffThreshold = 10.0
        return difference > diffThreshold ? 0.0 : 1.0 - difference / diffThreshold
    }

    func checkIfHasToRefreshAndUpdateThreshold(conf: Double, arConf: Double, situmConf: Double) -> Bool {
        let currentTimestamp = Date().timeIntervalSince1970 * 1000

        if arConf < 0.8 || situmConf < 0.8 {
            resetThreshold()
            return true
        }
print("CONSTANT_QUALITY_DECREASE_RATE:   ", CONSTANT_QUALITY_DECREASE_RATE)
        if currentRefreshThreshold.value > 0.20 && currentTimestamp - currentRefreshThreshold.timestamp > 1000 {
            currentRefreshThreshold.value -= CONSTANT_QUALITY_DECREASE_RATE
        }

        if conf > currentRefreshThreshold.value + 0.2 {
            currentRefreshThreshold.value = conf
            currentRefreshThreshold.timestamp = currentTimestamp
            dynamicRefreshThreshold = currentRefreshThreshold
            return true
        } else if conf < currentRefreshThreshold.value && currentTimestamp - currentRefreshThreshold.timestamp > 1000 && currentRefreshThreshold.value > 0.20 {
            currentRefreshThreshold.value -= QUALITY_THRESHOLD_DECREASE_RATE
            currentRefreshThreshold.timestamp = currentTimestamp
            dynamicRefreshThreshold = currentRefreshThreshold
            return false
        } else if currentTimestamp - currentRefreshThreshold.timestamp > 30000 {
            currentRefreshThreshold.value = max(conf, 0.2)
            currentRefreshThreshold.timestamp = currentTimestamp
            dynamicRefreshThreshold = currentRefreshThreshold
            return true
        }

        return false
    }

    private func resetThreshold() {
        currentRefreshThreshold = RefreshThreshold(value: 0.2, timestamp: Date().timeIntervalSince1970 * 1000)
        dynamicRefreshThreshold = currentRefreshThreshold
    }
    
    func getInfoParameters() -> [String: Double]{
        
        var infoDebug: [String: Double] = [
            "globalQuality": quality,
            "DynamicRefreshThreshold": Double(dynamicRefreshThreshold.value),
            "arConf": arConf,
            "situmConf" : situmConf
        
        ]
        
        return infoDebug
        
    }
    
    
    
}

