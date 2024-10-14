import Foundation

import RealityKit

func addDirectionalLight(to arView: ARView) {
    // Crear una entidad de anclaje para la luz
    let lightAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
    
    // Crear una luz direccional
    let directionalLight = DirectionalLight()
    directionalLight.light.intensity = 500
    directionalLight.light.color = .white
    
    // Ajustar la rotación de la luz si es necesario
    directionalLight.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])

    // Añadir la luz al ancla
    lightAnchor.addChild(directionalLight)
    
    // Añadir el ancla a la vista AR
    arView.scene.addAnchor(lightAnchor)
}
