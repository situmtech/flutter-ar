import Foundation
import RealityKit
import SitumSDK
import Combine
import SceneKit


class DynamicModelManager {
    

    private var featureCollection: ARFeatureCollection?
    var userInFence = false
    var geofenceName: String?
    
    
    /// Loads dynamic models based on `geofences`.
    func loadDynamicsModels(geofences: [SITGeofence], arView: ARView, mainAnchor: AnchorEntity) {
        for geofence in geofences {
            guard let customFields = geofence.customFields as? [String: Any] else {
                print("DynamicModelManager - customFields invalid or empty")
                continue
            }
            let geofenceName = geofence.name
            processGeofenceCustomFields(customFields:customFields, arView: arView, mainAnchor: mainAnchor, geofenceName: geofenceName)
        }
    }
    
    /// Processes customFields of a geofence and loads models if AR metadata is present
    private func processGeofenceCustomFields(customFields: [String: Any], arView: ARView, mainAnchor: AnchorEntity, geofenceName: String) {
        for (key, value) in customFields {
            guard key == "ar_metadata" else { continue }
            // Parse featureCollection
            guard let parsedFeatureCollection = parseARFeatureCollection(from: value) else {
                print("Error: Failed to parse feature collection from the provided data.")
                continue
            }
            self.featureCollection = parsedFeatureCollection
            userInFence = true
            self.geofenceName = geofenceName
            print("Geofence Name:   ", geofenceName)
            loadModels(arView: arView, mainAnchor: mainAnchor)
           
        }
    }
    
    
    /// Converts the value of `ar_metadata` to an `ARFeatureCollection` object
    private func parseARFeatureCollection(from metadata: Any) -> ARFeatureCollection? {
        guard let jsonString = metadata as? String else {
            print("Error: The metadata value is not a valid string")
            return nil
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Error: Failed to convert string to JSON data")
            return nil
        }
        
        do {
            let featureCollection = try JSONDecoder().decode(ARFeatureCollection.self, from: jsonData)
            return featureCollection
        } catch {
            print("Error parsing JSON: \(error)")
            return nil
        }
    }
    
    
    /// Load or update dynamic models from a list of features at random
    private func loadModels(
        arView: ARView,
        mainAnchor: AnchorEntity
    ) {
        
        guard let featureCollection = self.featureCollection else {
            print("Error: featureCollection es nil.")
            return
        }
        // Shuffle features to load them in random order
        let shuffledFeatures = featureCollection.features.shuffled()
        
        for (index, feature) in shuffledFeatures.enumerated().map({ ($0 + 1, $1) }) {
            guard feature.properties.type == "model" else {
                print("Feature ignored: It is not a model.")
                continue
            }
            
            let modelName = feature.properties.name
            let modelURL = feature.properties.url
            let scale = feature.properties.scale
            let orientation = feature.properties.orientation
            let position = feature.geometry.coordinates
            

            // Load a new model with the feature data
            loadDynamicModel(
                model: modelName,
                modelURL: modelURL,
                scale: scale,
                orientation: orientation,
                position: position,
                arView: arView,
                mainAnchor: mainAnchor,
                index: index
            )
            
        }
    }
    
    
    
    /// Load a specific model into the scene.
    private func loadDynamicModel(
        model: String,
        modelURL: String,
        scale: Float,
        orientation: [Float],
        position: [Double],
        arView: ARView,
        mainAnchor: AnchorEntity,
        index: Int
    ) {
        print("Loading model: \(model) from URL: \(modelURL)")
        
        do {
            // Cargar el modelo como ModelEntity
            let entity = try Entity.load(named: model + ".usdz")
            print("Entity loaded correctly: \(entity)")
            
            guard let modelEntity = findFirstModelEntity(in: entity) else {
                print("Error:A ModelEntity was not found in the model hierarchy\(model).")
                return
            }
            modelEntity.name = "dynamic_\(model)"
            
            // Configure model
            let cameraPosition = arView.cameraTransform.translation
            modelEntity.scale = SIMD3<Float>(scale, scale, scale)
                
            // Update model position
            self.setPositionAndOrientation(modelEntity:modelEntity, cameraPosition:cameraPosition, position: position, orientation: orientation, index:index)
             
            
            // Play animation if available
            if let animation = modelEntity.availableAnimations.first {
                modelEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            }
            
            mainAnchor.addChild(modelEntity)
            
            print("Model loaded correctly: \(modelEntity.name)")
            
        } catch {
            print("Error while loading model \(model): \(error.localizedDescription)")
        }
    }
    
    private func setPositionAndOrientation(
        modelEntity: Entity,
        cameraPosition: SIMD3<Float>,
        position: [Double],
        orientation: [Float],
        index: Int
    ) {
        // Check that the length of `position` is sufficient to access index 2
        guard position.count > 2 else {
            print("Error: The array position does not have enough elements.")
            return
        }
        
        if(index == 1){
            modelEntity.position = SIMD3<Float>(
                cameraPosition.x - Float.random(in: -5.0...5.0),
                cameraPosition.y + Float(position[2]),
                cameraPosition.z - 10.0
            )
        }else{
            modelEntity.position = SIMD3<Float>(
                cameraPosition.x - Float.random(in: -5.0...5.0),
                cameraPosition.y + Float(position[2]),
                cameraPosition.z - 1000.0
            )
        }
        
        
        // Apply orientation on X, Y, Z axes if available
        if orientation.count == 3 {
            let rotationX = simd_quatf(angle: orientation[0] * (.pi / 180), axis: SIMD3<Float>(1, 0, 0))
            let rotationY = simd_quatf(angle: orientation[1] * (.pi / 180), axis: SIMD3<Float>(0, 1, 0))
            let rotationZ = simd_quatf(angle: orientation[2] * (.pi / 180), axis: SIMD3<Float>(0, 0, 1))
            
            // Combine rotations in X, Y, Z
            modelEntity.orientation = simd_mul(simd_mul(rotationX, rotationY), rotationZ)
        }
        print("Model loaded :   ",modelEntity.name, "  in pose: ", modelEntity.position.y, "   ", modelEntity.position.z)
      
    }
        
    /// Function to find the first ModelEntity in an Entity hierarchy
    private func findFirstModelEntity(in entity: Entity) -> ModelEntity? {
        if let modelEntity = entity as? ModelEntity {
            return modelEntity
        }
        for child in entity.children {
            if let modelEntity = findFirstModelEntity(in: child) {
                return modelEntity
            }
        }
        return nil
    }
    
    /// Function to play animation if available
    private func playAnimationIfAvailable(for modelEntity: ModelEntity) {
        guard let animation = modelEntity.availableAnimations.first else {
            print("No animations available for this \(modelEntity.name).")
            return
        }
        
        print("Found animation: \(animation.name)")
        modelEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
    }
    
    
    func removeDynamicModels(arView: ARView, geofences: [SITGeofence]) {
        
        for geofence in geofences {
            guard let customFields = geofence.customFields as? [String: Any] else {
                print("DynamicModelManager - customFields invalid or empty")
                continue
            }
            
            
            if(self.geofenceName == geofence.name){
                
                
                arView.scene.anchors.forEach { anchor in
                    anchor.children.filter { $0.name.hasPrefix("dynamic_") }.forEach {
                        $0.removeFromParent()
                        print("Removed dynamic model: \($0.name)")
                    }
                }
            }
        }
    }

    
    func updateModelsBasedOnDistance(arView: ARView, cameraDepth: Double) {
        let cameraPosition = arView.cameraTransform.translation
        var minDistance: Float = 5000.0
        arView.scene.anchors.forEach { anchor in
            for model in anchor.children.filter({ $0.name.hasPrefix("dynamic_") }) {
                let distance = simd_distance(cameraPosition, model.position(relativeTo: nil))
                if distance < minDistance {
                    minDistance = distance
                }
            }
        }
        if abs(minDistance) > Float(cameraDepth) {
            print("Updating models. Nearest model is \(minDistance) meters away.")
            updateModelLocations(arView: arView)
        }
    }
    
    private func updateModelLocations(arView: ARView) {
            guard let featureCollection = self.featureCollection else {
                print("Error: featureCollection is nil.")
                return
            }
            let shuffledFeatures = featureCollection.features.shuffled()
            arView.scene.anchors.forEach { anchor in
                var dynamicModels = anchor.children.filter { $0.name.hasPrefix("dynamic_") }.shuffled()
                dynamicModels.forEach { $0.removeFromParent() }
                for (index, feature) in shuffledFeatures.enumerated() {
                    guard index < dynamicModels.count else { break }
                    let modelEntity = dynamicModels[index]
                    modelEntity.scale = SIMD3<Float>(
                        feature.properties.scale,
                        feature.properties.scale,
                        feature.properties.scale
                    )
                    setPositionAndOrientation(
                        modelEntity: modelEntity,
                        cameraPosition: arView.cameraTransform.translation,
                        position: feature.geometry.coordinates,
                        orientation: feature.properties.orientation,
                        index: index
                    )
                    anchor.addChild(modelEntity)
                    print("Updated model: \(modelEntity.name) at position: \(modelEntity.position)")
                }
            }
        }

    
    
}
    
    //Create Situm Arrow
    @available(iOS 15.0, *)
    func createArrowAnchor() -> AnchorEntity {
        let anchor = AnchorEntity()
        
        do {
            // Load model as ModelEntity
            guard let arrowEntity = try? ModelEntity.load(named: "arrowSitum.usdz") else {
                print("Error: The model could not be loaded as a ModelEntity.")
                return anchor
            }
            
            // Configure scale, orientation and position
            arrowEntity.scale = SIMD3<Float>(0.025, 0.025, 0.025)
            arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)
            
            // Set Situm color
            let customColor = UIColor(red: 40.0 / 255.0, green: 51.0 / 255.0, blue: 128.0 / 255.0, alpha: 1.0)
            
            // Apply color to model
            applyColorToEntityAndChildren(entity: arrowEntity, color: customColor)
            
            // Add model to anchor
            anchor.addChild(arrowEntity)
            
        } catch {
            print("Error loading arrow model: \(error.localizedDescription)")
        }
        
        return anchor
    }
    
    @available(iOS 15.0, *)
    func applyColorToEntityAndChildren(entity: Entity, color: UIColor) {
        if let modelEntity = entity as? ModelEntity {
            // create a completely matte material
            var material = PhysicallyBasedMaterial()
            // Configure base color
            material.baseColor = .init(tint: color)
            // Configure max roughness to to eliminate shine
            material.roughness = .init(floatLiteral: 1.0)
            // Configure min metallic
            material.metallic = .init(floatLiteral: 0.0)
            // Configure min specular
            material.specular = .init(floatLiteral: 0.0)
            // Assign the material to the model
            modelEntity.model?.materials = [material]
        }
        
        // Apply material to subentities recursively
        for child in entity.children {
            applyColorToEntityAndChildren(entity: child, color: color)
        }
    }
    
    
    struct ARFeature: Decodable {
        struct Properties: Decodable {
            let url: String
            let scale: Float
            let orientation: [Float]
            let floorId: Int
            let name: String
            let type: String
        }
        
        struct Geometry: Decodable {
            struct Coordinates: Decodable {
                let longitude: Double
                let latitude: Double
                let altitude: Double?
            }
            let type: String
            let coordinates: [Double]
        }
        
        let type: String
        let properties: Properties
        let geometry: Geometry
    }
    
    struct ARFeatureCollection: Decodable {
        let type: String
        let features: [ARFeature]
    }

