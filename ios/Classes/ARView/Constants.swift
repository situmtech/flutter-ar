import Foundation

struct Constants {
    
    // Refresh AR constants
    struct Refresh {
        static let extraRefreshTime = 5000
        
    }
    
    struct ARSettings {  
        static let minDistanceCameraDepth = Float(2.0)
        static let animationTransition = Double(0.5)
        static let zMaxPositionToPlaceModel = Float(15.0)
        static let zMinPositionToPlaceModel = Float(10.0)
        static let xPositionToPlaceModel = Float(5.0)
        static let zOutCameraDepth = Float(1000.0)
        static let arrowScale = Float(0.025)
        }
    struct Utils{
        static let toPI = Float(Float.pi / 180.0)
        static let toDegrees = Double(180.0 / Float.pi)
    }
    
    struct Colors{
        static let situmRed = 40.0 / 255.0
        static let situmGreen  = 51.0 / 255.0
        static let situmBlue = 128.0 / 255.0        
    }
    
    struct Lights{
        static let ambientLightIntensity = Float(600.0)
        static let attenuationRadius = Float(100.0)
        static let topLightIntensity = Float(4500.0)
        static let frontLightIntensity = Float(3000.0)
        static let direcctionalLightIntensity = Float(2400)
    }
    
    struct ARQuality{
        static let BUFFER_SIZE = 15
        static let requiredPositions = 10
        static let maxConfidence = 1.0
        static let minDistanceThreshold = 10.0

    }
    
}
