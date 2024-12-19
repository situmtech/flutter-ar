
import Foundation
import SceneKit
import CoreLocation
import SitumSDK


class HandlerARQuality {

    var arQuality: ARQuality

    init(arQuality: ARQuality) {
        self.arQuality = arQuality
    }

    @available(iOS 15.0, *)
    func updateRefreshing(coordinator: Coordinator?, hasToResetChangeFloor: Bool) {
        arQuality.hasToRefresh = true

        if arQuality.hasToResetWorld() {
            arQuality.hasToRefresh = arQuality.hasToResetWorld()
        } else {
            arQuality.hasToRefresh = false
        }

        if hasToResetChangeFloor {
            arQuality.hasToRefresh = true
        }

        if arQuality.hasToRefresh {
            let numRefresh = 1
            startRefreshing(numRefresh, coordinator: coordinator)
        } else if arQuality.refreshingTimer > 0 {
            refresh(coordinator: coordinator)
            arQuality.refreshingTimer -= 1
            if arQuality.refreshingTimer == 0 {
                stopRefreshing()
            }
        }

        coordinator?.setHasToReset(hasToRefresh: arQuality.hasToRefresh)
    }

    @available(iOS 15.0, *)
    func refresh(coordinator: Coordinator?) {
        let currentTimestamp = Int(Date().timeIntervalSince1970 * 1000) // Time in milliseconds
        if currentTimestamp > arQuality.timestampLastRefresh + Constants.Refresh.extraRefreshTime {
            if let coordinator = coordinator {
                coordinator.updatePOIs()
            }
            arQuality.timestampLastRefresh = currentTimestamp
        }
    }

    @available(iOS 15.0, *)
    func startRefreshing(_ numRefresh: Int, coordinator: Coordinator?) {
        refresh(coordinator: coordinator)
        arQuality.refreshingTimer = numRefresh
    }

    func stopRefreshing() {
        // Implement stop refreshing logic if necessary
    }

    @available(iOS 15.0, *)
    func updateArQuality(location: SITLocation, coordinator: Coordinator?, hasToResetChangeFloor: Bool) {
        updateRefreshing(coordinator: coordinator, hasToResetChangeFloor: hasToResetChangeFloor)
        arQuality.updateSitumLocation(location: location)

        // Unpacking optional camera coordinate values
        if let worldPosition = coordinator?.arView?.cameraTransform.translation,
           let worldRotation = coordinator?.arView?.cameraTransform.rotation {
  
            let position: SCNVector3 = SCNVector3(worldPosition.x, worldPosition.y, worldPosition.z)
            let rotation = SCNQuaternion(worldRotation.axis.x,
                                         worldRotation.axis.y,
                                         worldRotation.axis.z,
                                         worldRotation.angle)
            arQuality.updateARLocation(worldPosition: position, worldRotation: rotation)
        } else {
            print("Error: no se pudieron obtener los valores de la cámara")
        }
    }
}


