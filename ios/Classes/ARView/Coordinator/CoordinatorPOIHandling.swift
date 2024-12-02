// Coordinator+POIHandling.swift
import ARKit
import RealityKit
import SitumSDK

@available(iOS 15.0, *)
extension Coordinator {
    
    /// Updates the list of POIs and displays it in the scene.
    func updatePOIs() {
      
        guard let arView = arView, let initialLocation = locationManager.initialLocation else { return }
        
        // Find or create the anchor 'fixedPOIAnchor'.
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
               
        //Delete all previous POIs and texts
        fixedPOIAnchor.children.filter { $0.name.starts(with: "poiContainer_") }
                .forEach { $0.removeFromParent() }
        
        // Get list of POIs
        guard let poisList = self.poisStored["pois"] as? [[String: Any]] else {
            print("Error: No se encontró la clave 'pois' en el mapa de POIs")
            return
        }
        
        // Adding new POIs
        for (index, poi) in poisList.enumerated() {
            if let position = poi["position"] as? [String: Any],
               let cartesianCoordinate = position["cartesianCoordinate"] as? [String: Double],
               let floorIdentifier = position["floorIdentifier"] as? String,
               let x = cartesianCoordinate["x"],
               let y = cartesianCoordinate["y"],
               let name = poi["name"] as? String,
               floorIdentifier == String(Int(initialLocation.altitude)) {
                
                let transformedPosition = generateARKitPosition(x: Float(x), y: Float(y), currentLocation: initialLocation, arView: arView)
                
                // Create POI and text
                let iconUrlString = poi["iconUrl"] as? String ?? ""
                
                // Check if URL is correct
                guard let iconUrl = URL(string: iconUrlString) else {
                    print("Error: URL no válida para el icono del POI: \(name)")
                    continue
                }
                

                replaceTextureOnCylinder(url: iconUrl) { poiEntity in
                     guard let poiEntity = poiEntity else {
                         print("Error: No se pudo crear el disco para el POI")
                         return
                     }
                    
                        let containerEntity = Entity()
                        containerEntity.position = transformedPosition
                        containerEntity.name = "poiContainer_\(name)"
                    
                        // Configure POI
                        poiEntity.position = SIMD3<Float>(0, 0, 0)
                        poiEntity.name = "poi_\(name)"
                       
                        // Configure text
                        let textEntity = createTextEntity(text: name, poiPosition: SIMD3<Float>(0, 0, 0), arView: arView) // Coloca el texto encima del POI
                        textEntity.name = "text_\(name)"
       
                        // Add POI and text to container
                        containerEntity.addChild(poiEntity)
                        containerEntity.addChild(textEntity)
                       
                        // Add container to main anchor
                        fixedPOIAnchor.addChild(containerEntity)
                  
                    }
                
            }
        }
        self.updatePointsList()
        self.updateArrowPositionAndDirection()
    }
    
      
    /// Handles the updating of received POIs and updates them in the scene.
    func handlePoisUpdated(poisMap: [String: Any]) {
        poisStored = poisMap
        self.updatePOIs()
    }
    
    /// Updates the list of points in the scene.
    func updatePointsList() {
        guard let arView = arView, let initialLocation = locationManager.initialLocation else { return }
        
        // Find or create the anchor 'fixedPOIAnchor'
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
        
        // Delete all points from the route
        fixedPOIAnchor.children.filter { $0.name.starts(with: "point_")}
            .forEach { $0.removeFromParent() }
        
        self.storedTransformedPositions.removeAll()
        
        // I apply the transformation to all points of the route
        for (index, point) in self.pointsList.enumerated() {
            if let cartesianCoordinate = point["cartesianCoordinate"] as? [String: Double],
               let xPoint = cartesianCoordinate["x"],
               let yPoint = cartesianCoordinate["y"]{
                
                let transformedPosition = generateARKitPosition(
                    x: Float(xPoint),
                    y: Float(yPoint),
                    currentLocation: initialLocation,
                    arView: arView
                )
                self.storedTransformedPositions.append(transformedPosition)
                
            } else {
                print("Invalid point data: \(point)")
            }
            
            setTargetCoordinates(x: self.storedTransformedPositions[0].x, z: self.storedTransformedPositions[0].z)
        }
    }
    
    /// Displays the target point in the scene.
    func showPointTarget() {
        
        guard let arView = arView else { return }
        
        // Find the anchor and create if it doesn't exist
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
        
        // Delete point from existing route
        fixedPOIAnchor.children.filter { $0.name.starts(with: "point_") }
            .forEach { $0.removeFromParent() }
        
        // Create the sphere entity to mark the target point
        let poiEntity = createSphereEntity(radius: 0.35, color: .blue, transparency: 0.75)
        let targetPosition = SIMD3<Float>(Float(self.targetX), -0.5, Float(self.targetZ))
        poiEntity.position = targetPosition
        poiEntity.name = "point_"
        
        // Add to the anchor
        fixedPOIAnchor.addChild(poiEntity)
    }
    
    /// Sets the target coordinates.
    func setTargetCoordinates(x: Float, z: Float) {
        self.targetX = Double(x)
        self.targetZ = Double(z)
       
    }
}
