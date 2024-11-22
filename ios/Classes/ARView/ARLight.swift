import Foundation
import RealityKit

@available(iOS 15.0, *)
func setupLighting(arView: ARView) {
    // Crear un ancla para las luces
    
    let factorLight: Float = 0.3
    let lightAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
    
    // Luz ambiental para iluminar uniformemente toda la escena
    let ambientLight = Entity()
    let ambientLightComponent = PointLightComponent(
        color: .white,
        intensity: 20000*factorLight, // Incrementar intensidad para una iluminación más uniforme
        attenuationRadius: 100.0 // Asegurar cobertura total de la escena
    )
    ambientLight.components.set(ambientLightComponent)
    ambientLight.position = SIMD3<Float>(0, 5, 0) // Posicionar la luz en el centro superior
    lightAnchor.addChild(ambientLight)
    
    // Luz direccional desde arriba hacia abajo
    let directionalLightTop = DirectionalLight()
    directionalLightTop.light.intensity = 15000*factorLight
    directionalLightTop.light.color = .white
    directionalLightTop.position = SIMD3<Float>(0, 10, 0) // Luz desde arriba
    directionalLightTop.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
    lightAnchor.addChild(directionalLightTop)
    
    // Luz direccional desde el frente de la cámara
    let directionalLightFront = DirectionalLight()
    directionalLightFront.light.intensity = 10000*factorLight
    directionalLightFront.light.color = .white
    directionalLightFront.position = SIMD3<Float>(0, 0, 10) // Luz desde frente
    directionalLightFront.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    lightAnchor.addChild(directionalLightFront)
    
    // Luz direccional desde atrás
    let directionalLightBack = DirectionalLight()
    directionalLightBack.light.intensity = 8000*factorLight
    directionalLightBack.light.color = .white
    directionalLightBack.position = SIMD3<Float>(0, 0, -10) // Luz desde atrás
    directionalLightBack.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
    lightAnchor.addChild(directionalLightBack)
    
    // Luz direccional desde los lados
    let directionalLightLeft = DirectionalLight()
    directionalLightLeft.light.intensity = 8000*factorLight
    directionalLightLeft.light.color = .white
    directionalLightLeft.position = SIMD3<Float>(-10, 0, 0) // Luz desde la izquierda
    directionalLightLeft.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
    lightAnchor.addChild(directionalLightLeft)
    
    let directionalLightRight = DirectionalLight()
    directionalLightRight.light.intensity = 8000*factorLight
    directionalLightRight.light.color = .white
    directionalLightRight.position = SIMD3<Float>(10, 0, 0) // Luz desde la derecha
    directionalLightRight.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
    lightAnchor.addChild(directionalLightRight)
    
    // Añadir el ancla con todas las luces al ARView
    arView.scene.anchors.append(lightAnchor)
}
