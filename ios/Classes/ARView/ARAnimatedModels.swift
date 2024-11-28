import Foundation
import RealityKit
import SitumSDK


class DynamicModelManager {
    
    private var dynamicModels: [ModelEntity] = []
    private var featureCollection: ARFeatureCollection?

    var userInFence = false
    let distanceToUpdateModel = 20.0
    
    
    /// Carga modelos dinámicos basados en los `geofences`.
    func loadDynamicsModels(geofences: [SITGeofence], arView: ARView, mainAnchor: AnchorEntity) {
        for geofence in geofences {
            guard let customFields = geofence.customFields as? [String: Any] else {
                NSLog("DynamicModelManager - customFields no es del tipo esperado o está vacío")
                continue
            }

            processGeofenceCustomFields(customFields, arView: arView, mainAnchor: mainAnchor)
        }
    }

    /// Procesa los customFields de un geofence y carga modelos si hay metadatos AR
    private func processGeofenceCustomFields(_ customFields: [String: Any], arView: ARView, mainAnchor: AnchorEntity) {
        for (key, value) in customFields {
            guard key == "ar_metadata" else { continue }
            print("key value:    ", key, "     ", value)
            // Intentar parsear el featureCollection desde el valor
            if let featureCollection = parseARFeatureCollection(from: value) {
                userInFence = true
                // Procesar los features o cargar/actualizar modelos
                loadModels(featureCollection:featureCollection, arView: arView, mainAnchor: mainAnchor)
            } else {
                print("Error: No se pudo parsear el ARFeatureCollection.")
            }
        }
    }


    /// Convierte el valor de `ar_metadata` en un objeto `ARFeatureCollection`
    private func parseARFeatureCollection(from metadata: Any) -> ARFeatureCollection? {
        guard let jsonString = metadata as? String else {
            print("Error: El valor de metadata no es una cadena válida")
            return nil
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Error: No se pudo convertir la cadena a datos JSON")
            return nil
        }
        
        do {
            let featureCollection = try JSONDecoder().decode(ARFeatureCollection.self, from: jsonData)
            return featureCollection
        } catch {
            print("Error al parsear el JSON: \(error)")
            return nil
        }
    }


    /// Carga o actualiza los modelos dinámicos a partir de una lista de características de forma aleatoria
    private func loadModels(
        featureCollection: ARFeatureCollection,
        arView: ARView,
        mainAnchor: AnchorEntity
    ) {
        // Barajar las características para cargarlas en orden aleatorio
        let shuffledFeatures = featureCollection.features.shuffled()
        
        for (index, feature) in shuffledFeatures.enumerated().map({ ($0 + 1, $1) }) {
            guard feature.properties.type == "model" else {
                print("Feature ignorado: no es un modelo.")
                continue
            }

            let modelName = feature.properties.name
            let modelURL = feature.properties.url
            let scale = feature.properties.scale
            let orientation = feature.properties.orientation
            let position = feature.geometry.coordinates

            print("Model name:   ", modelName, "   scale:   ", scale)
            print("INDEX:    ", index)
             // Cargar un nuevo modelo con los datos del feature
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



    /// Carga un modelo específico en la escena.
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
        print("Cargando modelo: \(model) desde URL: \(modelURL)")

        do {
            // Cargar el modelo como ModelEntity
            let entity = try Entity.load(named: model + ".usdz")
            print("Entidad cargada correctamente: \(entity)")

            guard let modelEntity = findFirstModelEntity(in: entity) else {
                print("Error: No se encontró un ModelEntity en la jerarquía del modelo \(model).")
                return
            }

            // Configurar el modelo
            let cameraPosition = arView.cameraTransform.translation
            print("SCALE:   ", scale)
            modelEntity.scale = SIMD3<Float>(scale, scale, scale)

            // Actualizar la posición del modelo específico
            self.setPosition(modelEntity:modelEntity, cameraPosition:cameraPosition, index:index, position: position)

            // Aplicar orientación en los ejes X, Y, Z si está disponible
            if orientation.count == 3 {
                let rotationX = simd_quatf(angle: orientation[0] * (.pi / 180), axis: SIMD3<Float>(1, 0, 0))
                let rotationY = simd_quatf(angle: orientation[1] * (.pi / 180), axis: SIMD3<Float>(0, 1, 0))
                let rotationZ = simd_quatf(angle: orientation[2] * (.pi / 180), axis: SIMD3<Float>(0, 0, 1))
                
                // Combinar las rotaciones en X, Y, Z
                modelEntity.orientation = simd_mul(simd_mul(rotationX, rotationY), rotationZ)
            }

            modelEntity.name = "dynamic_\(model)"

            // Reproducir animación si está disponible
            if let animation = modelEntity.availableAnimations.first {
                print("Animación encontrada: \(animation.name)")
                modelEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            } else {
                print("No se encontraron animaciones disponibles para \(modelEntity.name).")
            }

            // Añadir al ancla principal
            mainAnchor.addChild(modelEntity)

            // Guardar en la lista de modelos dinámicos
            dynamicModels.append(modelEntity)

            print("Modelo cargado exitosamente: \(modelEntity.name)")

        } catch {
            print("Error al cargar el modelo \(model): \(error.localizedDescription)")
        }
    }

    private func setPosition(
        modelEntity: Entity,
        cameraPosition: SIMD3<Float>,
        index: Int,
        position: [Double]
    ) {
        // Verifica que la longitud de `position` sea suficiente para acceder al índice 2
        guard position.count > 2 else {
            print("Error: El array position no tiene suficientes elementos.")
            return
        }
        
        if index == 1 {
            modelEntity.position = SIMD3<Float>(
                cameraPosition.x - Float.random(in: -5.0...5.0),
                cameraPosition.y + Float(position[2]),
                cameraPosition.z - 5.0
            )
        } else {
            modelEntity.position = SIMD3<Float>(
                cameraPosition.x - Float.random(in: -5.0...5.0),
                cameraPosition.y + Float(position[2]),
                cameraPosition.z - 100.0
            )
        }
    }


    


    /// Función para buscar el primer ModelEntity en una jerarquía de Entity
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

    /// Función para reproducir animación si está disponible
    private func playAnimationIfAvailable(for modelEntity: ModelEntity) {
        guard let animation = modelEntity.availableAnimations.first else {
            print("No se encontraron animaciones disponibles para \(modelEntity.name).")
            return
        }

        print("Animación encontrada: \(animation.name)")
        modelEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
    }




    /// Configura y devuelve un modelo estático predefinido en un `AnchorEntity`.
   /* func setupDynamicModel() -> AnchorEntity {
        let fixedAnchorModel = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        do {
            let robotEntity = try ModelEntity.load(named: "Animated_Dragon_Three_Motion_Loops.usdz")
            robotEntity.scale = SIMD3<Float>(0.015, 0.015, 0.015)
            robotEntity.position = SIMD3<Float>(1.0, -0.25, -3.0)
            
            let rotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
            robotEntity.orientation = rotation

            if let animation = robotEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
                robotEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            }

            let tRexEntity = try ModelEntity.load(named: "T-Rex.usdz")
            tRexEntity.scale = SIMD3<Float>(0.015, 0.015, 0.015)
            tRexEntity.position = SIMD3<Float>(-2.0, -1.5, -20.0)
            
            if let animation = tRexEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
                tRexEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            }

            fixedAnchorModel.addChild(robotEntity)
            fixedAnchorModel.addChild(tRexEntity)

        } catch {
            print("Error al cargar el modelo animado: \(error.localizedDescription)")
        }

        return fixedAnchorModel
    }
    */
    func removeModels(geofences: [SITGeofence], from mainAnchor: AnchorEntity) {
        // Verifica y elimina modelos asociados a los geofences
        for geofence in geofences {
            if let customFields = geofence.customFields as? [String: Any] {
                for (key, value) in customFields {
                    if key == "ar_metadata", let modelName = value as? String {
                        print("Processing geofence with metadata: \(modelName)")
                        userInFence = false
                        // Buscar el modelo dinámico correspondiente
                        if let modelToRemove = dynamicModels.first(where: { $0.name == "dynamic_\(modelName)" }) {
                            modelToRemove.removeFromParent()
                            dynamicModels.removeAll { $0 == modelToRemove }
                            print("Removed dynamic model associated with geofence: \(modelName)")
                        }
                    }
                }
            }
        }

        // Recorre los hijos de `mainAnchor` y elimina los que coincidan con el prefijo "dynamic_"
        for child in mainAnchor.children {
            if child.name.hasPrefix("dynamic_") {
                child.removeFromParent()
                print("Removed model from mainAnchor with name: \(child.name)")
            }
        }

        // Reinicia la variable featureCollection
        featureCollection = nil
        print("Feature collection has been cleared.")

        print("All matching dynamic models and featureCollection have been removed.")
    }

    func updateModelsBasedOnDistance(arView: ARView) {
        let cameraPosition = arView.cameraTransform.translation
        var minDistance: Float = 5000.0
        var modelToUpdate: ModelEntity? // Variable para rastrear el modelo más lejano

        if self.userInFence {
            for model in self.dynamicModels {
                let modelPosition = model.position
                let distance = simd_distance(cameraPosition, modelPosition)

                print("Camera position: \(cameraPosition.x), \(cameraPosition.z)")
                print("Model position: \(modelPosition.x), \(modelPosition.z)")
                print("DISTANCE: \(distance)")

                // Actualiza la distancia mínima y almacena el modelo correspondiente
                if distance < minDistance {
                    minDistance = distance
                    modelToUpdate = model
                }
            }

            // Si la distancia mínima es mayor que el umbral, actualizamos el modelo
            if minDistance > Float(distanceToUpdateModel), let modelToUpdate = modelToUpdate {
                print("Updating model \(modelToUpdate.name) as it's \(minDistance) meters away from the camera.")
                updateModelLocation(for: modelToUpdate, arView: arView)
            }
        }
    }


    
    func updateModelLocation(for modelEntity: ModelEntity, arView: ARView) {
       
        func updateModelLocation(for modelEntity: ModelEntity, arView: ARView, index: Int) {
            let shuffledFeatures = featureCollection?.features.shuffled() ?? []

            for (index, feature) in shuffledFeatures.enumerated().map({ ($0 + 1, $1) }) {
                guard feature.properties.type == "model" else {
                    print("Feature ignorado: no es un modelo.")
                    continue
                }

                let modelName = feature.properties.name
                let scale = feature.properties.scale
                let orientation = feature.properties.orientation
                let position = feature.geometry.coordinates

                print("Model name:   ", modelName, "   scale:   ", scale)

                // Actualiza la posición del modelo existente
                let cameraPosition = arView.cameraTransform.translation
                // Actualizar la posición del modelo específico
                self.setPosition(modelEntity:modelEntity, cameraPosition:cameraPosition, index:index,position: position)
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
            print("Error: El modelo no se pudo cargar como ModelEntity.")
            return anchor
        }

        // Configurar escala, orientación y posición
        arrowEntity.scale = SIMD3<Float>(0.025, 0.025, 0.025)
        arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)

        // Definir el color personalizado con R=40, G=51, B=128
        let customColor = UIColor(red: 40.0 / 255.0, green: 51.0 / 255.0, blue: 128.0 / 255.0, alpha: 1.0)

        // Aplicar el color al modelo y sus subentidades
        applyColorToEntityAndChildren(entity: arrowEntity, color: customColor)

        // Añadir el modelo al ancla
        anchor.addChild(arrowEntity)

    } catch {
        print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
    }

    return anchor
}

// Función recursiva para aplicar un color a todas las subentidades
@available(iOS 15.0, *)
func applyColorToEntityAndChildren(entity: Entity, color: UIColor) {
    if let modelEntity = entity as? ModelEntity {
        // Crear un material completamente mate
        var material = PhysicallyBasedMaterial()
        // Configurar color base
        material.baseColor = .init(tint: color)
        // Configurar rugosidad máxima para eliminar brillos
        material.roughness = .init(floatLiteral: 1.0) // Rugosidad máxima (completamente mate)
        // Configurar metalicidad mínima
        material.metallic = .init(floatLiteral: 0.0) // Sin efecto metálico
        // Configurar reflectividad especular mínima
        material.specular = .init(floatLiteral: 0.0) // Sin reflectividad
        // Asignar el material al modelo
        modelEntity.model?.materials = [material]
    }

    // Aplicar el material a las subentidades recursivamente
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
