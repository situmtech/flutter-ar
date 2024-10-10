import Foundation
import ARKit
import RealityKit
import SitumSDK

/**
 ARSceneJuandler. Manage AR world.
 */
@available(iOS 13.0, *)
class ARSceneHandler: NSObject, ARSessionDelegate, SITLocationDelegate {
    
    /**
     Called once after initialization.
     */
    func setupSceneView(arSceneView: CustomARSceneView) {
        
    }
    
    /**
     Called once per frame.
     */
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
    
    }
    
    // MARK: LocationManager delegate.

    func locationManager(_ locationManager: any SITLocationInterface, didUpdate location: SITLocation) {
        
    }
    
    func locationManager(_ locationManager: any SITLocationInterface, didFailWithError error: (any Error)?) {
        
    }
    
    func locationManager(_ locationManager: any SITLocationInterface, didUpdate state: SITLocationState) {
        
    }
}
