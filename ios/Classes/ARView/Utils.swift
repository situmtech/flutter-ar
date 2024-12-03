import Foundation
import ARKit
import RealityKit
import CoreLocation
import MetalKit
import UIKit
import CoreGraphics
import SitumSDK


var timeElapsed: Float = 0.0


class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // Check if image is cached
        if let cachedImage = cache.object(forKey: url.absoluteString as NSString) {
            completion(cachedImage)
            return
        }
        
        // Start download
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Download error for image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: invalid HTTP")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("Error: No se pudo convertir la respuesta a una imagen.")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // Save image in cache
            self.cache.setObject(image, forKey: url.absoluteString as NSString)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
        
        task.resume()
    }
}

struct MidpointComponent: Component {
    var midpoint: SIMD3<Float>
}


@available(iOS 15.0, *)
func parsePois(pois: [SITPOI]) -> [[String: Any]] {
    var poisMap: [[String: Any]] = []

    for poi in pois {
        
        if let customFields = poi.customFields as? [String: Any] {
                    var shouldSkip = false
                    for (key, value) in customFields {
                        if key == "hide", let stringValue = value as? String, stringValue == "on_map" {
                                                       shouldSkip = true
                            break
                        }
                    }
                    if shouldSkip {
                        continue
                    }
                }

     
        let position = poi.position()
        let icon = poi.category.iconURL
       
        if let cartesianCoordinate = position.cartesianCoordinate {
            let name = poi.name
            let floorIdentifier = position.floorIdentifier

            let poiDict: [String: Any] = [
                "name": name,
                "position": [
                    "cartesianCoordinate": [
                        "x": cartesianCoordinate.x,
                        "y": cartesianCoordinate.y
                    ],
                    "floorIdentifier": floorIdentifier
                ],
                "iconUrl": "https://dashboard.situm.com" + icon.direction,
                "poiDestination": false
            ]
            poisMap.append(poiDict)
        } else {
            print("Situm> Cartesian coordinate not available for POI: \(poi.name)")
        }
        
        // Prepare the full URL
        let baseURL = "https://dashboard.situm.com"
        let iconPath = icon.direction
        let urlString = baseURL + iconPath
     
        // Check URL
        if let url = URL(string: urlString) {
            ImageCacheManager.shared.loadImage(from: url) { image in
                if let image = image {
                    print("Download image and save in cache to: \(poi.name)")
                }
            }
        } else {
            print("Error: invalid URL for POI icon: \(poi.name)")
        }
    }

    return poisMap
}

@available(iOS 15.0, *)
func createSphereEntity(radius: Float, color: UIColor, transparency: Float) -> ModelEntity {
    let sphereMesh = MeshResource.generateSphere(radius: radius)

    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

    let desaturatedColor = UIColor(hue: hue, saturation: saturation * 0.5, brightness: brightness, alpha: alpha * CGFloat(transparency))

    let material = SimpleMaterial(color: desaturatedColor, isMetallic: false)
    let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])

    return sphereEntity
}


@available(iOS 15.0, *)
func createTexturedDisk(with image: UIImage, diameter: Float) -> ModelEntity? {
    // Create the disk in RealityKit with the specified diameter
    let diskMesh = MeshResource.generatePlane(width: diameter, depth: diameter)
    let diskEntity = ModelEntity(mesh: diskMesh)
    
    // Create the texture from the circular image
    guard let cgImage = image.cgImage,
          let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) else {
        print("Error: Can not generate texture from image .")
        return nil
    }
    
    // Create a material to apply the texture on the disk
    var texturedMaterial = UnlitMaterial()
     texturedMaterial.baseColor = .texture(texture)
     texturedMaterial.opacityThreshold = 0.5

    
    // Assign the textured material to the disk
    diskEntity.model?.materials = [texturedMaterial]
    
    return diskEntity
}


@available(iOS 15.0, *)
func replaceTextureOnCylinder(url: URL, completion: @escaping (Entity?) -> Void) {
    
    let modelName = "cylinderNotRotated.usdz"

    do {
        // Load the model as an Entity
        let entity = try Entity.load(named: modelName)

        // Load new texture from URL
        ImageCacheManager.shared.loadImage(from: url) { image in
            guard let image = image else {
                print("Error loading image for texture.")
                completion(nil)
                return
            }

            //Convert UIImage to CGImage
            guard let cgImage = image.cgImage else {
                print("Error converting UIImage to CGImage.")
                completion(nil)
                return
            }

            // Generate the texture from the CGImage
            let options = TextureResource.CreateOptions(semantic: .color)
            guard let texture = try? TextureResource.generate(from: cgImage, options: options) else {
                print("Error generating texture from CGImage.")
                completion(nil)
                return
            }
            // Apply texture to all ModelEntity nodes
            applyTextureToModelEntities(in: entity, texture: texture)

            completion(entity)
        }
    } catch {
        print("Error loading model: \(error.localizedDescription)")
        completion(nil)
    }
}
@available(iOS 15.0, *)
func applyTextureToModelEntities(in entity: Entity, texture: TextureResource) {
   
    if var modelEntity = entity as? ModelEntity,
       var modelComponent = modelEntity.components[ModelComponent.self] as? ModelComponent {
        for index in modelComponent.materials.indices {
            var newMaterial = PhysicallyBasedMaterial()
            newMaterial.baseColor.texture = .init(texture)
            newMaterial.baseColor.tint = .white
            modelComponent.materials[index] = newMaterial           
        }
        modelEntity.components[ModelComponent.self] = modelComponent
    }

    // Recursively search in children
    for child in entity.children {
        applyTextureToModelEntities(in: child, texture: texture)
    }
}


@available(iOS 15.0, *)
func createTextEntity(text: String, poiPosition: SIMD3<Float>, arView: ARView) -> ModelEntity {
    //Generate the main text
    let mainMesh = MeshResource.generateText(
        text,
        extrusionDepth: 0.02,
        font: .systemFont(ofSize: 1.2),
        containerFrame: .zero,
        alignment: .center,
        lineBreakMode: .byWordWrapping
    )
    let mainMaterial = SimpleMaterial(color: .white, isMetallic: false)
    let mainTextEntity = ModelEntity(mesh: mainMesh, materials: [mainMaterial])
    mainTextEntity.scale = SIMD3<Float>(0.35, 0.35, 0.35)

    // Generate the text for the border
    let borderMesh = MeshResource.generateText(
        text,
        extrusionDepth: 0.025, // Slightly larger extrusion
        font: .systemFont(ofSize: 1.2),
        containerFrame: .zero,
        alignment: .center,
        lineBreakMode: .byWordWrapping
    )
    let borderMaterial = SimpleMaterial(color: .black, isMetallic: false)
    let borderTextEntity = ModelEntity(mesh: borderMesh, materials: [borderMaterial])
    borderTextEntity.scale = SIMD3<Float>(0.355, 0.355, 0.355) // Same scale as the main text
    borderTextEntity.position = SIMD3<Float>(0, 0, -0.002) // Adjust slightly backwards

    // Container to keep both texts together
    let containerEntity = ModelEntity()
    containerEntity.addChild(borderTextEntity) // Add border text first
    containerEntity.addChild(mainTextEntity)  // Add main text

    // Position the container directly above the POI
    containerEntity.position = SIMD3<Float>(poiPosition.x, poiPosition.y + 1.05, poiPosition.z)

    // Center text on X axis
    let bounds = containerEntity.visualBounds(relativeTo: nil)
    let textWidth = bounds.extents.x
    containerEntity.position.x -= textWidth / 2.0

    return containerEntity
}

func updateMovementPois(arView: ARView, destinationPoiName: String) {
    // Find the anchor that contains the POIs
    guard let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) else {
        print("Error: No se encontró el ancla 'fixedPOIAnchor'")
        return
    }

    let poiContainerNameDestination = "poiContainer_\(destinationPoiName)"
    
    //Loop through anchor children (POIs)
    for child in fixedPOIAnchor.children {
        if child.name.starts(with: "poiContainer_") {
            if let poiName = child.name.split(separator: "_").last {
                let poiContainerName = "poiContainer_\(poiName)"
                  
                if poiContainerName == poiContainerNameDestination {
                    handleDestinationPoi(arView: arView, poiContainerName: poiContainerName, deltaTime: 0.01)
                }
                
                updatePOIsOscillationAndOrientation(arView: arView, poiContainerName: poiContainerName)
               
            }
        }
    }
}

// Function to handle the destination POI in a special way
func handleDestinationPoi(arView: ARView, poiContainerName: String, deltaTime: Float) {
    guard let poiContainerEntity = arView.scene.findEntity(named: poiContainerName) else {
        print("No se encontró el POI con el nombre: \(poiContainerName)")
        return
    }

    let cameraPosition = arView.cameraTransform.translation

    // Orient the POI towards the camera
    let poiPosition = poiContainerEntity.position(relativeTo: nil)
    poiContainerEntity.look(at: cameraPosition, from: poiPosition, relativeTo: nil)

    // Apply correction so that the front face of the POI faces the camera
    let frontRotationCorrection = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
    poiContainerEntity.orientation = simd_mul(poiContainerEntity.orientation, frontRotationCorrection)

    // Increase elapsed time
    timeElapsed += deltaTime

    // Scale settings for zoom in and zoom out
    let minScale = SIMD3<Float>(repeating: 1.0)  // Min scale
    let maxScale = SIMD3<Float>(repeating: 2.0)  // Max scale

    // oscillation factor
    let oscillationFactor = (sin(timeElapsed * 1.7) + 1) / 2

    // Interpolate between minScale and maxScale using the oscillation factor
    let newScale = minScale + (maxScale - minScale) * oscillationFactor
    
    // Apply the new scale to the POI
    poiContainerEntity.scale = newScale
   
}


// Function to apply swing and yaw to a specific POI
func updatePOIsOscillationAndOrientation(arView: ARView, poiContainerName: String) {
    guard let poiContainerEntity = arView.scene.findEntity(named: poiContainerName) else {
        print("No se encontró el POI con el nombre: \(poiContainerName)")
        return
    }
    
    // Configuration oscilation
    let maxAngle: Float = 20.0 * (.pi / 180.0) // Oscillation limit in radians (±20 degrees)
    let oscillationSpeed: Float = 1.7 // veloticy oscilation

    // Oscilation time
    let timeFactor = Float(CACurrentMediaTime()) * oscillationSpeed
    let oscillationAngle = maxAngle * sin(timeFactor)
 
    let cameraPosition = arView.cameraTransform.translation

    // Find POI and orientation to camera
    if let poiEntity = poiContainerEntity.children.first(where: { $0.name.starts(with: "poi_") }) {
     
        let poiPosition = poiEntity.position(relativeTo: nil)
        poiEntity.look(at: cameraPosition, from: poiPosition, relativeTo: nil)

        let frontRotationCorrection = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
        poiEntity.orientation = simd_mul(poiEntity.orientation, frontRotationCorrection)

        let oscillationRotation = simd_quatf(angle: oscillationAngle, axis: SIMD3<Float>(0, 1, 0))
        poiEntity.orientation = simd_mul(poiEntity.orientation, oscillationRotation)
    }

    // Orientation text to camera
    if let textEntity = poiContainerEntity.children.first(where: { $0.name.starts(with: "text_") }) {
        // Text over POI
        textEntity.position = SIMD3<Float>(0, 1.05, 0)

        // Center the text relative to the POI
        let bounds = textEntity.visualBounds(relativeTo: textEntity.parent)
        let textWidth = bounds.extents.x
        textEntity.position.x -= bounds.center.x // Center horizontally using the center of the text
        textEntity.position.z -= bounds.center.z // Ensuring depth centering

        // Orient text towards the camera
        let textPosition = textEntity.position(relativeTo: nil)
        textEntity.look(at: cameraPosition, from: textPosition, relativeTo: nil)

        // Prevent text from being reversed
        let textRotationCorrection = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
        textEntity.orientation = simd_mul(textEntity.orientation, textRotationCorrection)
    }
}



func rotateIconPoiAndText(arView: ARView) {
    if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
        // Rotate on Y axes
        let rotationAngle: Float = .pi / 360 // Update 1 degree
        let rotationIncrement = simd_quatf(angle: rotationAngle, axis: SIMD3<Float>(0, 1, 0))
        
        for child in fixedPOIAnchor.children {
            // Rotar la entidad contenedora
            if child.name.starts(with: "poiContainer_") {
                child.orientation = simd_mul(child.orientation, rotationIncrement)
            }
        }
    }
}

func updatePOIOrientationToCamera(arView: ARView) {
    guard let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity else {
        return
    }

    let cameraPosition = arView.cameraTransform.translation

    for child in fixedPOIAnchor.children {
        // Verify if the entity is a POI container
        if child.name.starts(with: "poiContainer_") {
            // Calculate POI position
            let poiPosition = child.position(relativeTo: nil)

            // Orient the POI towards the camera
            if let poiEntity = child.children.first(where: { $0.name.starts(with: "poi_") }) {
                poiEntity.look(at: cameraPosition, from: poiPosition, relativeTo: nil)
            }

            // Adjust and center text
            if let textEntity = child.children.first(where: { $0.name.starts(with: "text_") }) {
                //Keep text above POI
                textEntity.position = SIMD3<Float>(0, 1.05, 0)

                // Center the text relative to the POI
                let bounds = textEntity.visualBounds(relativeTo: textEntity.parent)
                let textWidth = bounds.extents.x
                textEntity.position.x -= bounds.center.x //Center horizontally using the center of the text
                textEntity.position.z -= bounds.center.z // Ensuring depth centering

                // Orient text towards the camera
                textEntity.look(at: cameraPosition, from: textEntity.position(relativeTo: nil), relativeTo: nil)

                // Prevent text from being reversed
                let textRotationCorrection = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                textEntity.orientation = simd_mul(textEntity.orientation, textRotationCorrection)
            }
        }
    }
}

func areLastThreeValuesDistinct(locationBuffer: [String?], currentIndex: Int) -> Bool {
    // Make sure the buffer has at least 3 values ​​to compare
    guard locationBuffer.count >= 3 else {
        return false
    }

    // Gets the last three values ​​stored in the buffer in a circular fashion
    let lastIndex1 = (currentIndex - 1 + locationBuffer.count) % locationBuffer.count
    let lastIndex2 = (currentIndex - 2 + locationBuffer.count) % locationBuffer.count
    let lastIndex3 = (currentIndex - 3 + locationBuffer.count) % locationBuffer.count
    
    guard let lastValue1 = locationBuffer[lastIndex1],
          let lastValue2 = locationBuffer[lastIndex2],
          let lastValue3 = locationBuffer[lastIndex3] else {
        // Returns false if any of the last three values ​​is nil
        return false
    }
    
    // Create a set with the last three values
    let lastThreeValues: Set<String> = [lastValue1, lastValue2, lastValue3]

    // Iterate through the rest of the buffer and check if any of them match the last three values.
    for i in 0..<locationBuffer.count {
        if i != lastIndex1 && i != lastIndex2 && i != lastIndex3 {
            if let location = locationBuffer[i], lastThreeValues.contains(location) {
                return false
            }
        }
    }
    
    return true
}

func resfreshByChangeFloor(location: SITLocation, currentIndex: inout Int, hasToResetChangeFloor: inout Bool, locationBuffer: inout [String?]) {
       hasToResetChangeFloor = false
       locationBuffer[currentIndex] = location.position.floorIdentifier
       currentIndex = (currentIndex + 1) % locationBuffer.count // Update index
       
       if areLastThreeValuesDistinct(locationBuffer: locationBuffer, currentIndex: currentIndex) {
           print("Los últimos tres valores son distintos del resto de la lista.")
           hasToResetChangeFloor = true
       } else {
           print("Los últimos tres valores no son distintos del resto de la lista.")
       }
   }

extension simd_float4x4 {
    func eulerAngles() -> (x: Float, y: Float, z: Float) {
        let sy = sqrt(self.columns.0.x * self.columns.0.x + self.columns.1.x * self.columns.1.x)
        
        let singular = sy < 1e-6 // Casi cero
        var x: Float, y: Float, z: Float
        
        if !singular {
            x = atan2(self.columns.2.y, self.columns.2.z)
            y = atan2(-self.columns.2.x, sy)
            z = atan2(self.columns.1.x, self.columns.0.x)
        } else {
            x = atan2(-self.columns.1.z, self.columns.1.y)
            y = atan2(-self.columns.2.x, sy)
            z = 0
        }
        
        return (x, y, z)
    }
}


extension UIView {
    func showToast(message: String, duration: TimeInterval = 2.0) {
        let toastContainer = UIView(frame: CGRect())
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastContainer.alpha = 0.0
        toastContainer.layer.cornerRadius = 10
        toastContainer.clipsToBounds = true

        let toastLabel = UILabel(frame: CGRect())
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.text = message
        toastLabel.numberOfLines = 0

        toastContainer.addSubview(toastLabel)
        self.addSubview(toastContainer)

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 10),
            toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -10),
            toastLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 10),
            toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -10),

            toastContainer.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            toastContainer.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -100),
            toastContainer.widthAnchor.constraint(lessThanOrEqualToConstant: self.frame.width - 40)
        ])

        UIView.animate(withDuration: Constants.ARSettings.animationTransition, animations: {
            toastContainer.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: Constants.ARSettings.animationTransition, delay: duration, options: .curveEaseOut, animations: {
                toastContainer.alpha = 0.0
            }) { _ in
                toastContainer.removeFromSuperview()
            }
        }
    }
}


