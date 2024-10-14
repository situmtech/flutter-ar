import Foundation
import RealityKit

//Create Situm Arrow
func createArrowAnchor() -> AnchorEntity {
    let anchor = AnchorEntity()

    do {
        let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
        arrowEntity.scale = SIMD3<Float>(0.025, 0.025, 0.025)
        arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)
        anchor.addChild(arrowEntity)
    } catch {
        print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
    }

    return anchor
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
