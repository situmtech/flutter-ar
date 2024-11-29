import Foundation
import RealityKit
import SitumSDK
import Combine
import SceneKit


class DynamicModelManager {
    
    private var dynamicModels: [ModelEntity] = []
    private var featureCollection: ARFeatureCollection?
    
    var userInFence = false
    
    
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
            
            print("MODEL POSE:   ",modelEntity.name, "     ", modelEntity.position.y, "   ", modelEntity.position.z)
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
    
    func removeDynamicModels() {
        // Filtrar todos los modelos cuyo nombre comience con "dynamic_"
        let modelsToRemove = dynamicModels.filter { $0.name.hasPrefix("dynamic_") }
        
        // Eliminar cada uno de los modelos encontrados
        modelsToRemove.forEach { modelToRemove in
            modelToRemove.removeFromParent() // Elimina el modelo de su entidad madre
            dynamicModels.removeAll { $0 == modelToRemove } // Elimina del arreglo dynamicModels
            print("Removed dynamic model: \(modelToRemove.name)")
        }
    }

    
    func updateModelsBasedOnDistance(arView: ARView, cameraDepth: Double) {
        let cameraPosition = arView.cameraTransform.translation
        var minDistance: Float = 5000.0
        //var modelToUpdate: ModelEntity? // Variable para rastrear el modelo más lejano
        
        if self.userInFence {
            for model in self.dynamicModels {
                let modelPosition = model.position
                print("Model position   ", model.name, "     ", model.position.y, "  , ",  model.position.z)
                let distance = simd_distance(cameraPosition, modelPosition)
                // Actualiza la distancia mínima y almacena el modelo correspondiente
                if distance < minDistance {
                    minDistance = distance
                }
            }
            
            // Si la distancia mínima es mayor que el umbral, actualizamos el modelo
            print("Min distance:  ", minDistance)
            if abs(minDistance) > Float(cameraDepth) {
                print("Updating model. it's \(minDistance) meters away from the camera!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!.")
                updateModelLocation(arView: arView)
            }
        }
    }
    
    func updateModelLocation(arView: ARView) {
        // Filtrar modelos que tienen el prefijo "dynamic_" y barajarlos para iteración aleatoria
        let dynamicModels = self.dynamicModels.filter { $0.name.hasPrefix("dynamic_") }.shuffled()

        // Iterar sobre los modelos dinámicos filtrados y barajados
        for (index, modelEntity) in dynamicModels.enumerated() {
            // Remover el modelo del ancla para evitar duplicados
            modelEntity.removeFromParent()

            // Obtener la posición de la cámara
            let cameraPosition = arView.cameraTransform.translation

            // Actualizar la posición del modelo específico
            if index == 1 {
                modelEntity.position = SIMD3<Float>(
                    cameraPosition.x - Float.random(in: -5.0...5.0),
                    cameraPosition.y,
                    cameraPosition.z - 5.0
                )
            } else {
                modelEntity.position = SIMD3<Float>(
                    cameraPosition.x - Float.random(in: -5.0...5.0),
                    cameraPosition.y,
                    cameraPosition.z - 100.0
                )
            }

            // Reagregar el modelo al ancla principal
            if let mainAnchor = arView.scene.anchors.first(where: { $0 is AnchorEntity }) {
                mainAnchor.addChild(modelEntity)
            }

            print("Modelo actualizado: \(modelEntity.name) a posición: \(modelEntity.position)")
        }
    }
    
    
   /* func highlightPoiDestination(arView: ARView, destinationPoiName: String) {
        // Buscar el POI por su nombre en la escena
        let poiContainerName = "poiContainer_\(destinationPoiName)"
        guard let poiContainerEntity = arView.scene.findEntity(named: poiContainerName) else {
            print("No se encontró el POI con el nombre: \(poiContainerName)")
            return
        }

        // Crear las transformaciones de escala
        let scaleUp = SIMD3<Float>(1.5, 1.5, 1.5) // Aumenta el tamaño
        let scaleDown = SIMD3<Float>(1.0, 1.0, 1.0) // Vuelve al tamaño original
        
        // Usamos el método `move(to:)` o `scale(to:)` con animación
        // Animación de escala: aumentar el tamaño
        let scaleUpTransform = Transform(scale: scaleUp)
        let scaleDownTransform = Transform(scale: scaleDown)
        
        // Aplicar la animación de escala en un bloque de animación
        poiContainerEntity.move(to: scaleUpTransform, relativeTo: poiContainerEntity.parent, duration: 1.0, timingFunction: .easeInOut)

        // Después de 1 segundo, disminuir el tamaño
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            poiContainerEntity.move(to: scaleDownTransform, relativeTo: poiContainerEntity.parent, duration: 1.0, timingFunction: .easeInOut)
        }

        // Repetir la animación para crear el efecto de pulsación
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.highlightPoiDestination(arView: arView, destinationPoiName: destinationPoiName)
        }
    }
*/





    
    
    
    
    
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

