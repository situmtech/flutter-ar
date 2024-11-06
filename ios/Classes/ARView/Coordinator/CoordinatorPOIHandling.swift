// Coordinator+POIHandling.swift
import ARKit
import RealityKit
import SitumSDK

@available(iOS 15.0, *)
extension Coordinator {
    
    /// Actualiza la lista de POIs y la muestra en la escena.
    func updatePOIs() {
      
        guard let arView = arView, let initialLocation = locationManager.initialLocation else { return }
        
        // Buscar o crear el ancla 'fixedPOIAnchor'
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
               
        // Eliminar todos los POIs y textos anteriores
        fixedPOIAnchor.children.filter { $0.name.starts(with: "poiContainer_") }
                .forEach { $0.removeFromParent() }
        
        // Obtener lista de POIs
        guard let poisList = self.poisStored["pois"] as? [[String: Any]] else {
            print("Error: No se encontró la clave 'pois' en el mapa de POIs")
            return
        }
       
        print("floor id:   ", initialLocation.altitude)
        // Añadir los nuevos POIs
        for (index, poi) in poisList.enumerated() {
            if let position = poi["position"] as? [String: Any],
               let cartesianCoordinate = position["cartesianCoordinate"] as? [String: Double],
               let floorIdentifier = position["floorIdentifier"] as? String,
               let x = cartesianCoordinate["x"],
               let y = cartesianCoordinate["y"],
               let name = poi["name"] as? String,
               floorIdentifier == String(Int(initialLocation.altitude)) {
                
                let transformedPosition = generateARKitPosition(x: Float(x), y: Float(y), currentLocation: initialLocation, arView: arView)
                
                // Crear POI y texto
                let iconUrlString = poi["iconUrl"] as? String ?? ""
                
                // Asegúrate de usar la URL correcta
                guard let iconUrl = URL(string: iconUrlString) else {
                    print("Error: URL no válida para el icono del POI: \(name)")
                    continue
                }
                
                createDiskEntityWithImageFromURL(radius: 0.8, thickness: 0.2, url: iconUrl) { poiEntity in
                        guard let poiEntity = poiEntity else {
                            print("Error: No se pudo crear el disco para el POI")
                            return
                        }
                    
                        let containerEntity = Entity()
                        containerEntity.position = transformedPosition
                        containerEntity.name = "poiContainer_\(index)"
                    
                        // Configurar el POI
                        poiEntity.position = SIMD3<Float>(0, 0, 0) // Centrado en el contenedor
                        poiEntity.name = "poi_\(index)"
                       
                        // Configurar el texto
                        let textEntity = createTextEntity(text: name, poiPosition: SIMD3<Float>(0, 0.3, 0), arView: arView) // Coloca el texto encima del POI
                        textEntity.name = "text_\(index)"
                       
                        // Añadir POI y texto al contenedor
                        containerEntity.addChild(poiEntity)
                        containerEntity.addChild(textEntity)
                       
                        // Añadir el contenedor al ancla principal
                        fixedPOIAnchor.addChild(containerEntity)
                       
                        addPointLightToScene(at: transformedPosition, arView: arView)
                  
                    }
                
            }
        }
        self.updatePointsList()
    }
    
    /// Maneja la actualización de los POIs recibidos y los actualiza en la escena.
    func handlePoisUpdated(poisMap: [String: Any]) {
        poisStored = poisMap
        self.updatePOIs()
    }
    
    /// Actualiza la lista de puntos en la escena.
    func updatePointsList() {
        guard let arView = arView, let initialLocation = locationManager.initialLocation else { return }
        
        // Buscar o crear el ancla 'fixedPOIAnchor'
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
        
        // Eliminar todos los puntos de la ruta
        fixedPOIAnchor.children.filter { $0.name.starts(with: "point_")}
            .forEach { $0.removeFromParent() }
        
        self.storedTransformedPositions.removeAll()
        
        // Aplico la transformación a todos los puntos de la ruta
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
    
    /// Muestra el punto objetivo en la escena.
    func showPointTarget() {
        
        guard let arView = arView else { return }
        
        // Buscar el ancla y crear si no existe
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
        
        // Eliminar el punto de la ruta existente
        fixedPOIAnchor.children.filter { $0.name.starts(with: "point_") }
            .forEach { $0.removeFromParent() }
        
        // Crear la entidad de la esfera para marcar el punto objetivo
        let poiEntity = createSphereEntity(radius: 0.35, color: .blue, transparency: 0.75)
        let targetPosition = SIMD3<Float>(Float(self.targetX), -0.5, Float(self.targetZ))  // Establecer y como -0.5 o cualquier valor apropiado
        poiEntity.position = targetPosition
        poiEntity.name = "point_" // Dar un nombre único a la esfera
        
        // Agregar la esfera al ancla
        fixedPOIAnchor.addChild(poiEntity)
    }
    
    /// Establece las coordenadas del objetivo.
    func setTargetCoordinates(x: Float, z: Float) {
        self.targetX = Double(x)
        self.targetZ = Double(z)
        
        print("x_target: \(self.targetX), z_target: \(self.targetZ)")
    }
}
