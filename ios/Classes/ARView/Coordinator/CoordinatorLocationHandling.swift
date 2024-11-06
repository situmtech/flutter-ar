// Coordinator+LocationHandling.swift
import RealityKit
import ARKit
import CoreLocation
import simd
import SitumSDK


@available(iOS 15.0, *)
extension Coordinator {

    /// Maneja la actualización de ubicación desde Situm.
    func handleLocationUpdate(location: SITLocation) {
        
        // Verifica si las coordenadas son opcionales y convierte floorIdentifier de String a Double
        if let cartesianCoordinate = location.position.cartesianCoordinate,
           let floorIdentifierAsDouble = Double(location.position.floorIdentifier) {
            let xSitum = cartesianCoordinate.x
            let ySitum = cartesianCoordinate.y
            let yawSitum = Double(location.cartesianBearing.radians()) // Convertir SITAngle a Double
            
            // Llama al método que actualiza la ubicación en la escena
            updateLocation(xSitum: xSitum, ySitum: ySitum, yawSitum: yawSitum, floorIdentifier: floorIdentifierAsDouble)
            
        } else {
            print("Datos inválidos recibidos en la notificación o conversión de floorIdentifier fallida: \(location)")
        }
    }
    
    /// Actualiza la posición en la escena en función de las coordenadas de Situm.
    func updateLocation(xSitum: Double, ySitum: Double, yawSitum: Double, floorIdentifier: Double) {
        
        let newLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: ySitum, longitude: xSitum),
            altitude: floorIdentifier,
            horizontalAccuracy: kCLLocationAccuracyBest,
            verticalAccuracy: kCLLocationAccuracyBest,
            course: yawSitum,
            speed: 0,
            timestamp: Date()
        )
        locationManager.initialLocation = newLocation
    }
    
    /// Genera una posición en ARKit usando las coordenadas de Situm y la ubicación actual.
    func generateARKitPosition(x: Float, y: Float, currentLocation: CLLocation, arView: ARView) -> SIMD3<Float> {
        
        // Obtener el yaw de la cámara respecto al norte
        guard let cameraBearing = getCameraYawRespectToNorth() else {
            return SIMD3<Float>(0, 0, 0) // Retorna un valor por defecto si no se pudo obtener el yaw
        }
        
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        let cameraHorizontalRotation = simd_quatf(angle: cameraBearing, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        let course = -currentLocation.course // Cambiamos el signo del yaw para invertir izquierda y derecha
        
        // Normalizar el curso en el rango [-π, π]
        let courseNormalized = fmod(course + .pi, 2 * .pi) - .pi
        
        let situmBearingDegrees = courseNormalized * (180.0 / .pi) + 90.0
        let situmBearingInRadians = Float(situmBearingDegrees) * (.pi / 180.0)
        let situmBearingMinusRotation = simd_quatf(angle: situmBearingInRadians, axis: SIMD3<Float>(0.0, -1.0, 0.0))
        
        let relativePoiPosition = SIMD3<Float>(
            x - Float(currentLocation.coordinate.longitude),
            0,
            y - Float(currentLocation.coordinate.latitude)
        )
        
        let positionsMinusSitumRotated = situmBearingMinusRotation.act(relativePoiPosition)
        
        // Rotar la posición ajustada basándose en la rotación horizontal de la cámara
        var positionRotatedAndTranslatedToCamera = cameraHorizontalRotation.act(positionsMinusSitumRotated)
        
        // Trasladar la posición al sistema de la cámara
        positionRotatedAndTranslatedToCamera.x = cameraPosition.x + positionRotatedAndTranslatedToCamera.x
        positionRotatedAndTranslatedToCamera.z = cameraPosition.z - positionRotatedAndTranslatedToCamera.z
        positionRotatedAndTranslatedToCamera.y = cameraPosition.y - 1
        
        return positionRotatedAndTranslatedToCamera
    }
    
    /// Calcula la distancia a la cámara en el plano XZ.
    func calculateDistanceToCamera(x: Float, z: Float) -> Float {
        guard let arView = arView else { return 0.0 }
        let distanceToCamera = simd_distance(SIMD2<Float>(arView.cameraTransform.translation.x, arView.cameraTransform.translation.z),
                                             SIMD2<Float>(x, z))
        return distanceToCamera
    }
    
    /// Calcula el ángulo hacia el objetivo a partir de la posición de la cámara.
    func calculateAngleToTarget() -> Float? {
        guard let arView = arView else { return nil }
        
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        
        // Crear el vector desde la cámara hasta el objetivo en el plano XZ
        let directionToTarget = SIMD2<Float>(Float(self.targetX) - cameraPosition.x, Float(self.targetZ) - cameraPosition.z)
        let normalizedDirectionToTarget = normalize(directionToTarget)
        
        // Calcular el ángulo hacia el objetivo
        let angleToTarget = atan2(normalizedDirectionToTarget.y, normalizedDirectionToTarget.x)
        let angleDifference = angleToTarget + .pi / 2.0
        
        return angleDifference
    }
    
    /// Obtiene el yaw de la cámara respecto al norte.
    func getCameraYawRespectToNorth() -> Float? {
        // Obtener el yaw original de la cámara
        guard let yaw = arView?.session.currentFrame?.camera.eulerAngles.y else {
            return nil
        }
        
        // Ajustar el yaw para que siga tus necesidades:
        // 0° será frente, +90° derecha, -90° izquierda, y 180° atrás
        let adjustedYaw = -yaw // Cambiamos el signo del yaw para invertir izquierda y derecha
        // Asegurarnos de que el valor ajustado esté dentro del rango [-π, π]
        let normalizedYaw = fmod(adjustedYaw + .pi, 2 * .pi) - .pi
        
        return normalizedYaw
    }
}

