import Foundation
import RealityKit
import SitumSDK
//Create Situm Arrow
@available(iOS 15.0, *)
func createArrowAnchor() -> AnchorEntity {
    let anchor = AnchorEntity()

    do {
        // Cargar el modelo como ModelEntity
        guard let arrowEntity = try? ModelEntity.load(named: "arrowSitumColor.usdz") else {
            print("Error: El modelo no se pudo cargar como ModelEntity.")
            return anchor
        }

        // Configurar escala, orientación y posición
        arrowEntity.scale = SIMD3<Float>(0.03, 0.03, 0.03)
        arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)

        // Definir el color personalizado con R=40, G=51, B=128
        let customColor = UIColor(red: 40.0 / 255.0, green: 51.0 / 255.0, blue: 128.0 / 255.0, alpha: 1.0)

        // Aplicar el color al modelo y sus subentidades
        applyColorToEntityAndChildren(entity: arrowEntity, color: customColor)


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
func applyColorToEntityAndChildren(entity: Entity, color: UIColor) {
    if var modelComponent = entity.components[ModelComponent.self] as? ModelComponent {
        // Crear un material simple con el color deseado
        let colorMaterial = SimpleMaterial(color: color, isMetallic: false)

        // Reemplazar todos los materiales de la entidad
        modelComponent.materials = Array(repeating: colorMaterial, count: modelComponent.materials.count)
        entity.components[ModelComponent.self] = modelComponent
    }

    // Recorrer las entidades hijas y aplicar el color
    for child in entity.children {
        applyColorToEntityAndChildren(entity: child, color: color)
    }
}





func loadDynamicsModels(geofences: [SITGeofence], arView: ARView, mainAnchor: AnchorEntity,  dynamicModels: inout [ModelEntity]){
    
    for geofence in geofences {
        if let customFields = geofence.customFields as? [String: Any] {
            for (key, value) in customFields {
                if(key == "ar_metadata_ios"){
                    NSLog("\(key): \(value)")
                    let model = String(describing: value)                   
                    loadDynamicModel(model: model, arView: arView, mainAnchor: mainAnchor, dynamicModels: &dynamicModels)
                    
                }
            }
        } else {
            NSLog("ARSceneHandler - customFields no es del tipo esperado o está vacío")
        }
    }
    
}


func loadDynamicModel(model: String, arView: ARView, mainAnchor: AnchorEntity, dynamicModels: inout [ModelEntity]){
    
    print("Model to load!:   ", model)
    
    do {
        let cameraPosition = arView.cameraTransform.translation
        let modelEntity = try ModelEntity.load(named: model)
        modelEntity.scale = SIMD3<Float>(0.015, 0.015, 0.015)
        modelEntity.position = SIMD3<Float>(cameraPosition.x - Float.random(in: -3.0...3.0), cameraPosition.y - 1.5, cameraPosition.z - Float.random(in: 10.0...20.0))
        modelEntity.name = "dynamic_" + model

        if let animation = modelEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
            modelEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
        }
           
        mainAnchor.addChild(modelEntity)
        if let modelEntity = try ModelEntity.load(named: model) as? ModelEntity {
            dynamicModels.append(modelEntity)
        } else {
            print("Failed to cast modelEntity to ModelEntity")
        }


        
    } catch {
        print("Error al cargar el modelo animado: \(error.localizedDescription)")
    }    

}


func setupDynamicModel() -> AnchorEntity{
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
