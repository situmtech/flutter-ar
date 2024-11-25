import Foundation
import RealityKit
import SitumSDK


class DynamicModelManager {
    
    private var dynamicModels: [ModelEntity] = []
    var userInFence = false
    
    
    /// Carga modelos dinámicos basados en los `geofences`.
    func loadDynamicsModels(geofences: [SITGeofence], arView: ARView, mainAnchor: AnchorEntity) {
        for geofence in geofences {
            if let customFields = geofence.customFields as? [String: Any] {
                for (key, value) in customFields {
                    if key == "ar_metadata" {
                        NSLog("\(key): \(value)")
                        print("key value:    ", key, "     ", value)
                        
                        let modelsString = String(describing: value)
                        let modelNames = modelsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        
                        userInFence = true
                        
                        for model in modelNames {
                            // Buscar si el modelo ya está cargado
                            if let existingModel = dynamicModels.first(where: { $0.name == "dynamic_\(model)" }) {
                                // Si ya existe, actualizar posición
                                updateModelLocation(for: existingModel, arView: arView)
                            } else {
                                // Si no existe, cargarlo como nuevo
                                loadDynamicModel(model: model, arView: arView, mainAnchor: mainAnchor)
                            }
                        }
                    }
                }
            } else {
                NSLog("DynamicModelManager - customFields no es del tipo esperado o está vacío")
            }
        }
    }


    /// Carga un modelo específico en la escena.
    func loadDynamicModel(model: String, arView: ARView, mainAnchor: AnchorEntity) {
        print("Model to load!:   ", model)
        do {
            let cameraPosition = arView.cameraTransform.translation

            // Cargar el modelo como Entity
            let entity = try Entity.load(named: model + ".usdz")
            print("Entidad cargada correctamente: \(entity)")

            // Buscar el primer ModelEntity en la jerarquía
            guard let modelEntity = findFirstModelEntity(in: entity) else {
                print("Error: No se encontró un ModelEntity en la jerarquía del modelo \(model).")
                return
            }

            // Configurar el ModelEntity
            modelEntity.scale = SIMD3<Float>(0.015, 0.015, 0.015)
            modelEntity.position = SIMD3<Float>(
                cameraPosition.x - Float.random(in: -3.0...3.0),
                cameraPosition.y - 1.0,
                cameraPosition.z - Float.random(in: 5.0...20.0)
            )
            modelEntity.name = "dynamic_" + model

            // Reproducir la animación si está disponible
            playAnimationIfAvailable(for: modelEntity)

            // Añadir el modelo al anchor principal
            mainAnchor.addChild(modelEntity)

            // Agregar el modelo a la lista de modelos dinámicos
            dynamicModels.append(modelEntity)

            print("Modelo cargado exitosamente: \(modelEntity.name)")

        } catch {
            print("Error al cargar el modelo: \(error.localizedDescription)")
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
    func setupDynamicModel() -> AnchorEntity {
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
                // Verificar si el nombre coincide con algún geofence
                let geofenceMatch = geofences.contains { geofence in
                    if let customFields = geofence.customFields as? [String: Any],
                       let modelName = customFields["ar_metadata"] as? String {
                        return child.name == "dynamic_\(modelName)"
                    }
                    return false
                }

                if geofenceMatch {
                    child.removeFromParent()
                    print("Removed model from mainAnchor with name: \(child.name)")
                }
            }
        }

        print("All matching dynamic models have been removed.")
    }

    
    func updateModelLocation(for modelEntity: ModelEntity, arView: ARView) {
        let cameraPosition = arView.cameraTransform.translation
        
        // Actualizar la posición del modelo específico
        modelEntity.position = SIMD3<Float>(
            cameraPosition.x - Float.random(in: -3.0...3.0),
            cameraPosition.y - 1.0,
            cameraPosition.z - Float.random(in: 5.0...20.0)
        )
        
        // Reproducir la animación si está disponible
        if let animation = modelEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
            modelEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
        }
        
        print("Updated position of model: \(modelEntity.name)")
    }

    /// Obtiene todos los modelos dinámicos cargados.
    func getDynamicModels() -> [ModelEntity] {
        return dynamicModels
    }

    /// Limpia todos los modelos dinámicos cargados.
    func clearDynamicModels() {
        dynamicModels.removeAll()
    }
}




//Create Situm Arrow
@available(iOS 15.0, *)
func createArrowAnchor() -> AnchorEntity {
    let anchor = AnchorEntity()

    do {
        // Cargar el modelo como ModelEntity
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


