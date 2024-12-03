import Foundation
import RealityKit

@available(iOS 15.0, *)
func setupLighting(arView: ARView) {
    // Create an anchor for the lights
    let lightAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
 
    // Ambient light to evenly illuminate the entire scene
    let ambientLight = Entity()
    let ambientLightComponent = PointLightComponent(
        color: .white,
        intensity: Constants.Lights.ambientLightIntensity, // Increase intensity for more uniform illumination
        attenuationRadius: Constants.Lights.attenuationRadius // Ensure full coverage of the scene
    )
    ambientLight.components.set(ambientLightComponent)
    ambientLight.position = SIMD3<Float>(0, 5, 0) // Position the light in the top center
    lightAnchor.addChild(ambientLight)
    
    // Directional light from top to bottom
    let directionalLightTop = DirectionalLight()
    directionalLightTop.light.intensity = Constants.Lights.topLightIntensity
    directionalLightTop.light.color = .white
    directionalLightTop.position = SIMD3<Float>(0, 10, 0) // Light from above
    directionalLightTop.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
    lightAnchor.addChild(directionalLightTop)
   
    // Directional light from the front of the camera
    let directionalLightFront = DirectionalLight()
    directionalLightFront.light.intensity =  Constants.Lights.frontLightIntensity
    directionalLightFront.light.color = .white
    directionalLightFront.position = SIMD3<Float>(0, 0, 10) //Light from the front
    directionalLightFront.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    lightAnchor.addChild(directionalLightFront)
  
    // Directional light from behind
    let directionalLightBack = DirectionalLight()
    directionalLightBack.light.intensity = Constants.Lights.direcctionalLightIntensity
    directionalLightBack.light.color = .white
    directionalLightBack.position = SIMD3<Float>(0, 0, 2) // Light from behind
    directionalLightBack.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
    lightAnchor.addChild(directionalLightBack)
   
   
    // Directional light from the sides
    let directionalLightLeft = DirectionalLight()
    directionalLightLeft.light.intensity = Constants.Lights.direcctionalLightIntensity
    directionalLightLeft.light.color = .white
    directionalLightLeft.position = SIMD3<Float>(-10, 0, 0) // Light from the left
    directionalLightLeft.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
    lightAnchor.addChild(directionalLightLeft)
    
   
    let directionalLightRight = DirectionalLight()
    directionalLightRight.light.intensity = Constants.Lights.direcctionalLightIntensity
    directionalLightRight.light.color = .white
    directionalLightRight.position = SIMD3<Float>(10, 0, 0) // Light from the right
    directionalLightRight.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
    lightAnchor.addChild(directionalLightRight)
    
    // Add anchor with all lights to ARView
    arView.scene.anchors.append(lightAnchor)
   
}
