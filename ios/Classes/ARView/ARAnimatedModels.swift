import Foundation
import RealityKit
import SitumSDK
//Create Situm Arrow
func createArrowAnchor() -> AnchorEntity {
    let anchor = AnchorEntity()

    do {
        let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
        arrowEntity.scale = SIMD3<Float>(0.015, 0.015, 0.015)
        arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)
        anchor.addChild(arrowEntity)
    } catch {
        print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
    }

    return anchor
}

func loadDynamicsModels(geofences: [SITGeofence], arView: ARView, mainAnchor: AnchorEntity,  dynamicModels: inout [ModelEntity]){
    
    for geofence in geofences {
        if let customFields = geofence.customFields as? [String: Any] {
            for (key, value) in customFields {
                if(key == "ar_metadata"){
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
        modelEntity.position = SIMD3<Float>(cameraPosition.x - Float.random(in: -3.0...3.0), cameraPosition.y - 1.5, cameraPosition.z - Float.random(in: 5.0...15.0))
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
