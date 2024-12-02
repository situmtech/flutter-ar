// Coordinator+LocationHandling.swift
import RealityKit
import ARKit
import CoreLocation
import simd
import SitumSDK


@available(iOS 15.0, *)
extension Coordinator {

    /// Handles location updates from Situm.
    func handleLocationUpdate(location: SITLocation) {
        
        // Check if coordinates are optional and convert floorIdentifier from String to Double
        if let cartesianCoordinate = location.position.cartesianCoordinate,
           let floorIdentifierAsDouble = Double(location.position.floorIdentifier) {
            let xSitum = cartesianCoordinate.x
            let ySitum = cartesianCoordinate.y
            let yawSitum = Double(location.cartesianBearing.radians()) // Convertir SITAngle a Double
            
            // Calls the method that updates the location in the scene
            updateLocation(xSitum: xSitum, ySitum: ySitum, yawSitum: yawSitum, floorIdentifier: floorIdentifierAsDouble)
            
        } else {
            print("Datos inválidos recibidos en la notificación o conversión de floorIdentifier fallida: \(location)")
        }
    }
    
    /// Updates the position in the scene based on Situm coordinates.
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
    
    /// Generates a position in ARKit using Situm coordinates and the current location.
    func generateARKitPosition(x: Float, y: Float, currentLocation: CLLocation, arView: ARView) -> SIMD3<Float> {
        
        // Get the camera yaw relative to north
        guard let cameraBearing = getCameraYawRespectToNorth() else {
            return SIMD3<Float>(0, 0, 0) // Returns a default value if yaw could not be obtained.
        }
        
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        let cameraHorizontalRotation = simd_quatf(angle: cameraBearing, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        let course = -currentLocation.course // We change the sign of the yaw to invert left and right
        
        // Normalize the course in the range [-π, π]
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
        
        // Rotate the adjusted position based on the horizontal rotation of the camera
        var positionRotatedAndTranslatedToCamera = cameraHorizontalRotation.act(positionsMinusSitumRotated)
        
        // Transfer position to camera system
        positionRotatedAndTranslatedToCamera.x = cameraPosition.x + positionRotatedAndTranslatedToCamera.x
        positionRotatedAndTranslatedToCamera.z = cameraPosition.z - positionRotatedAndTranslatedToCamera.z
        positionRotatedAndTranslatedToCamera.y = cameraPosition.y - 1
        
        return positionRotatedAndTranslatedToCamera
    }
    
    /// Calculates the distance to the camera in the XZ plane.
    func calculateDistanceToCamera(x: Float, z: Float) -> Float {
        guard let arView = arView else { return 0.0 }
        let distanceToCamera = simd_distance(SIMD2<Float>(arView.cameraTransform.translation.x, arView.cameraTransform.translation.z),
                                             SIMD2<Float>(x, z))
        return distanceToCamera
    }
    
    
    /// Gets the yaw of the camera relative to north.
    func getCameraYawRespectToNorth() -> Float? {
        // Obtener el yaw original de la cámara
        guard let yaw = arView?.session.currentFrame?.camera.eulerAngles.y else {
            return nil
        }
        
        // Adjust the yaw to suit your needs:
        // 0° will be forward, +90° right, -90° left, and 180° back
        let adjustedYaw = -yaw // We change the sign of the yaw to invert left and right
        //Make sure the adjusted value is within the range [-π, π]
        let normalizedYaw = fmod(adjustedYaw + .pi, 2 * .pi) - .pi
        
        return normalizedYaw
    }
}

