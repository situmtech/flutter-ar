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
            
            print("Before loading dynamic model")
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
    
    private func checkAndDownloadModel(model: String, modelURL: String) -> URL? {
        let fileManager = FileManager.default

        // Sanitize model name
        let sanitizedModelName = model.replacingOccurrences(of: "-", with: "_")
        
        // Check if file exists in the bundle
        if let bundleURL = Bundle.main.url(forResource: sanitizedModelName, withExtension: "usdz") {
            print("Model found in bundle: \(bundleURL.path)")
            return bundleURL
        }

        // Define local file URL in Caches directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let localFileURL = cachesDirectory.appendingPathComponent("\(sanitizedModelName).usdz")

        if fileManager.fileExists(atPath: localFileURL.path) {
            print("Model found locally at: \(localFileURL.path)")
            return localFileURL
        }

        // Ensure the model URL ends with .usdz
        var fullModelURL = modelURL
        if !modelURL.hasSuffix(".usdz") {
            fullModelURL += ".usdz"
        }

        print("Downloading model from: \(fullModelURL)")

        guard let url = URL(string: fullModelURL) else {
            print("Error: Invalid model URL.")
            return nil
        }

        let downloadSemaphore = DispatchSemaphore(value: 0)
        var downloadError: Error?

        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                print("Error downloading model: \(error.localizedDescription)")
                downloadError = error
            } else if let tempURL = tempURL {
                do {
                    // Check file size
                    let attributes = try fileManager.attributesOfItem(atPath: tempURL.path)
                    if let fileSize = attributes[.size] as? Int64, fileSize > 0 {
                        print("Downloaded file size: \(fileSize) bytes")
                    } else {
                        print("Error: Downloaded file is empty.")
                        downloadError = NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "File is empty"])
                        return
                    }

                    // Move file to Caches directory
                    if fileManager.fileExists(atPath: localFileURL.path) {
                        try fileManager.removeItem(at: localFileURL)
                    }
                    try fileManager.moveItem(at: tempURL, to: localFileURL)
                    print("Model downloaded and saved to: \(localFileURL.path)")
                } catch {
                    print("Error saving downloaded model: \(error.localizedDescription)")
                    downloadError = error
                }
            }
            downloadSemaphore.signal()
        }.resume()

        downloadSemaphore.wait()

        if downloadError != nil || !fileManager.fileExists(atPath: localFileURL.path) {
            print("Error: Model \(sanitizedModelName) could not be downloaded or validated.")
            return nil
        }

        return localFileURL
    }




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
        print("Loading model: \(model)")

        // Verificar y obtener la ruta local o del bundle del modelo
        guard let localFileURL = checkAndDownloadModel(model: model, modelURL: modelURL) else {
            print("Error: Model \(model) could not be found or downloaded.")
            return
        }

        do {
            // Cargar el modelo como ModelEntity desde la ruta local
            let entity = try Entity.load(contentsOf: URL(fileURLWithPath: localFileURL.path))
            print("Entity loaded correctly: \(entity)")

            guard let modelEntity = findFirstModelEntity(in: entity) else {
                print("Error: A ModelEntity was not found in the model hierarchy \(model).")
                return
            }
            modelEntity.name = "dynamic_\(model)"

            // Configurar el modelo
            let cameraPosition = arView.cameraTransform.translation
            modelEntity.scale = SIMD3<Float>(scale, scale, scale)

            // Actualizar posición del modelo
            self.setPositionAndOrientation(
                modelEntity: modelEntity,
                cameraPosition: cameraPosition,
                position: position,
                orientation: orientation,
                index: index
            )

            // Reproducir animación si está disponible
            if let animation = modelEntity.availableAnimations.first {
                modelEntity.playAnimation(
                    animation.repeat(),
                    transitionDuration: Constants.ARSettings.animationTransition,
                    startsPaused: false
                )
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
                cameraPosition.x - Float.random(in: -Constants.ARSettings.xPositionToPlaceModel...Constants.ARSettings.xPositionToPlaceModel),
                cameraPosition.y + Float(position[2]),
                cameraPosition.z - Float.random(in: Constants.ARSettings.zMinPositionToPlaceModel...Constants.ARSettings.zMaxPositionToPlaceModel) 
            )
        }else{
            modelEntity.position = SIMD3<Float>(
                cameraPosition.x - Float.random(in: -Constants.ARSettings.xPositionToPlaceModel...Constants.ARSettings.xPositionToPlaceModel),
                cameraPosition.y + Float(position[2]),
                cameraPosition.z - Float.random(in: Constants.ARSettings.zMinOutCameraDepth...Constants.ARSettings.zMaxOutCameraDepth)
            )
        }
        
        
        // Apply orientation on X, Y, Z axes if available
        if orientation.count == 3 {
            let rotationX = simd_quatf(angle: orientation[0] * Constants.Utils.toPI, axis: SIMD3<Float>(1, 0, 0))
            let rotationY = simd_quatf(angle: orientation[1] * Constants.Utils.toPI, axis: SIMD3<Float>(0, 1, 0))
            let rotationZ = simd_quatf(angle: orientation[2] * Constants.Utils.toPI, axis: SIMD3<Float>(0, 0, 1))
            
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
        modelEntity.playAnimation(animation.repeat(), transitionDuration: Constants.ARSettings.animationTransition, startsPaused: false)
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
        // Get camera position
        let cameraPosition = arView.cameraTransform.translation
        
        // Track closest and farthest models
        var minDistance: Float = Float.greatestFiniteMagnitude
        var maxDistance: Float = 0
        var nearestModel: Entity?
        var farthestModel: Entity?
        
        // Iterate over dynamic models to find nearest and farthest
        arView.scene.anchors.forEach { anchor in
            for model in anchor.children.filter({ $0.name.hasPrefix("dynamic_") }) {
                let distance = simd_distance(cameraPosition, model.position(relativeTo: nil))
                if distance < minDistance {
                    minDistance = distance
                    nearestModel = model
                }
                if distance > maxDistance {
                    maxDistance = distance
                    farthestModel = model
                }
            }
        }
        
        // Log distances for debugging
        if let nearest = nearestModel, let farthest = farthestModel {
            print("Nearest model: \(nearest.name) at \(minDistance)m, Farthest model: \(farthest.name) at \(maxDistance)m.")
        }
        
        // Only update models if the nearest model is farther than cameraDepth
        if let nearest = nearestModel, minDistance > Float(cameraDepth) {
            updateModelLocations(arView: arView, nearestModel: nearest, farthestModel: farthestModel)
        } else {
            print("The nearest model is closer than the camera depth, no update performed.")
        }
    }


    private func updateModelLocations(arView: ARView, nearestModel: Entity?, farthestModel: Entity?) {
        guard let nearestModel = nearestModel as? ModelEntity, let farthestModel = farthestModel as? ModelEntity else {
            print("Error: Nearest or farthest model is missing or not a ModelEntity.")
            return
        }
        
        // Get camera position
        let cameraPosition = arView.cameraTransform.translation

        // Move the farthest model in front of the camera (z = -1 relative to the camera)
        let yFarthestModel = farthestModel.position.y
        farthestModel.removeFromParent()
        //farthestModel.position = cameraPosition + SIMD3<Float>(0, 0, -1)
        farthestModel.position = SIMD3<Float>(
            cameraPosition.x - Float.random(in: -Constants.ARSettings.xPositionToPlaceModel...Constants.ARSettings.xPositionToPlaceModel),
            cameraPosition.y + yFarthestModel,
            cameraPosition.z - Float.random(in: Constants.ARSettings.zMinPositionToPlaceModel...Constants.ARSettings.zMaxPositionToPlaceModel)
        )

        arView.scene.anchors.first?.addChild(farthestModel)

        // Move the nearest model to z = 100
        let yNearestModel = nearestModel.position.y
        nearestModel.removeFromParent()
        nearestModel.position = SIMD3<Float>(
            cameraPosition.x - Float.random(in: -Constants.ARSettings.xPositionToPlaceModel...Constants.ARSettings.xPositionToPlaceModel),
            cameraPosition.y + yNearestModel,
            cameraPosition.z - Float.random(in: Constants.ARSettings.zMinOutCameraDepth...Constants.ARSettings.zMaxOutCameraDepth)
        )
        
        
        arView.scene.anchors.first?.addChild(nearestModel)

        // Debug information
        print("Moved farthest model: \(farthestModel.name) in front of the camera.")
        print("Moved nearest model: \(nearestModel.name) to z = 100.")
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
            arrowEntity.scale = SIMD3<Float>(Constants.ARSettings.arrowScale, Constants.ARSettings.arrowScale, Constants.ARSettings.arrowScale)
            arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)
            
            // Set Situm color
            let customColor = UIColor(red: Constants.Colors.situmRed, green: Constants.Colors.situmGreen, blue: Constants.Colors.situmBlue, alpha: 1.0)
            
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

