import Foundation
import ARKit
import RealityKit
import CoreLocation
import MetalKit
import UIKit
import SitumSDK

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // Verificar si la imagen ya está en caché
        if let cachedImage = cache.object(forKey: url.absoluteString as NSString) {
            completion(cachedImage)
            return
        }
        
        // Iniciar la tarea de descarga
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error al descargar la imagen: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Respuesta HTTP no válida")
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
            
            // Almacenar la imagen en caché
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
        // Llamar a la función position() para obtener el valor de SITPoint
        let position = poi.position()
        let icon = poi.category.iconURL
           
        // Desenrolla el cartesianCoordinate de forma segura
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
                "iconUrl": "https://dashboard.situm.com" + icon.direction
            ]
            poisMap.append(poiDict)
        } else {
            print("Situm> Cartesian coordinate not available for POI: \(poi.name)")
        }
        
        // Preparar la URL completa
        let baseURL = "https://dashboard.situm.com"
        let iconPath = icon.direction // Asegúrate de que `icon` contenga solo la parte de la ruta
        let urlString = baseURL + iconPath
     
        // Validar la URL
        if let url = URL(string: urlString) {
            ImageCacheManager.shared.loadImage(from: url) { image in
                if let image = image {
                    print("Imagen descargada y almacenada en caché para: \(poi.name)")
                }
            }
        } else {
            print("Error: URL no válida para el icono del POI: \(poi.name)")
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
func createDiskEntityWithImage(radius: Float, image: UIImage) -> ModelEntity {
    let thickCircularEntity = ModelEntity()
    let thickness = Float(0.1)
    let segments = 10

    guard let cgImage = image.cgImage else {
        print("Error: No se pudo convertir UIImage a CGImage.")
        return ModelEntity()
    }
    
    let flippedImage = image.withHorizontallyFlippedOrientation()
    guard let flippedCGImage = flippedImage.cgImage else {
        print("Error: No se pudo convertir UIImage flípeada a CGImage.")
        return ModelEntity()
    }

    guard let originalTexture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)),
          let flippedTexture = try? TextureResource.generate(from: flippedCGImage, options: .init(semantic: .color)) else {
        print("Error: No se pudo generar la textura desde las imágenes.")
        return ModelEntity()
    }

    // Usar UnlitMaterial para respetar la transparencia del canal alfa
    var originalMaterial = UnlitMaterial()
    originalMaterial.baseColor = .texture(originalTexture)
    originalMaterial.opacityThreshold = 0.5  // Preserva la transparencia del PNG

    var flippedMaterial = UnlitMaterial()
    flippedMaterial.baseColor = .texture(flippedTexture)
    flippedMaterial.opacityThreshold = 0.5  // Preserva la transparencia del PNG

    let segmentSpacing = thickness / Float(segments - 1)

    for i in 0..<segments {
        let planeMesh = MeshResource.generatePlane(width: 2 * radius, depth: 2 * radius)
        let frontPlaneEntity = ModelEntity(mesh: planeMesh, materials: [originalMaterial])
        let backPlaneEntity = ModelEntity(mesh: planeMesh, materials: [flippedMaterial])
        
        frontPlaneEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        backPlaneEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 0, 1))

        let offset = Float(i) * segmentSpacing - (thickness / 2)
        frontPlaneEntity.position = SIMD3(0, 0, offset)
        backPlaneEntity.position = SIMD3(0, 0, offset)
        
        thickCircularEntity.addChild(frontPlaneEntity)
        thickCircularEntity.addChild(backPlaneEntity)
    }

    return thickCircularEntity
}


@available(iOS 15.0, *)
func addPointLightToScene(at position: SIMD3<Float>, arView: ARView) {
    let lightEntity = PointLight()
    lightEntity.light.intensity = 25000  // Ajusta según el nivel de brillo que desees
    lightEntity.light.color = .white
    
    let lightAnchor = AnchorEntity(world: position)
    lightAnchor.addChild(lightEntity)
    arView.scene.addAnchor(lightAnchor)
}


@available(iOS 15.0, *)
func addLightToScene(arView: ARView) {
    let lightEntity = DirectionalLight()
    lightEntity.light.intensity = 15000  // Aumenta la intensidad según el nivel de iluminación deseado
    lightEntity.light.color = .white
    lightEntity.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
    
    let lightAnchor = AnchorEntity(world: SIMD3<Float>(0, 3, 0)) // Posición de la luz sobre los POIs
    lightAnchor.addChild(lightEntity)
    arView.scene.addAnchor(lightAnchor)
}



@available(iOS 15.0, *)
func createDiskEntityWithImageFromURL(radius: Float, thickness: Float, url: URL, completion: @escaping (ModelEntity?) -> Void) {
    ImageCacheManager.shared.loadImage(from: url) { image in
        guard let image = image else {
            completion(nil)
            return
        }
        
        let diskEntity = createDiskEntityWithImage(radius: radius, image: image)
        completion(diskEntity)
    }
}


@available(iOS 15.0, *)
func createTextEntity(text: String, poiPosition: SIMD3<Float>, arView: ARView) -> ModelEntity {
    let mesh = MeshResource.generateText(
        text,
        extrusionDepth: 0.02,
        font: .systemFont(ofSize: 1.0),
        containerFrame: .zero,
        alignment: .center,
        lineBreakMode: .byWordWrapping
    )
    
    let material = SimpleMaterial(color: .white, isMetallic: false)
    let textEntity = ModelEntity(mesh: mesh, materials: [material])
    
    // Escalar el texto y colocarlo directamente encima del POI en posición fija
    textEntity.scale = SIMD3<Float>(0.25, 0.25, 0.25)
    textEntity.position = SIMD3<Float>(poiPosition.x, poiPosition.y + 0.75, poiPosition.z) // Posición fija en Y para colocarlo encima del POI

    // Ajustar la posición del texto para centrarlo horizontalmente
    let bound = textEntity.visualBounds(relativeTo: nil)
    let textWidth = bound.extents.x
    textEntity.position.x -= textWidth / 2.0

    
    return textEntity
}



func rotateIconPoiAndText(arView: ARView) {
    if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
        // Definir una rotación incremental en el eje Y (continua)
        let rotationAngle: Float = .pi / 360 // Un pequeño ángulo en cada actualización (1 grado)
        let rotationIncrement = simd_quatf(angle: rotationAngle, axis: SIMD3<Float>(0, 1, 0))
        
        for child in fixedPOIAnchor.children {
            // Rotar la entidad contenedora
            if child.name.starts(with: "poiContainer_") {
                child.orientation = simd_mul(child.orientation, rotationIncrement)
            }
        }
    }
}



func areLastThreeValuesDistinct(locationBuffer: [String?], currentIndex: Int) -> Bool {
    // Asegurarse de que el buffer tenga al menos 3 valores para comparar
    guard locationBuffer.count >= 3 else {
        return false
    }

    // Obtiene los últimos tres valores guardados en el buffer de forma circular
    let lastIndex1 = (currentIndex - 1 + locationBuffer.count) % locationBuffer.count
    let lastIndex2 = (currentIndex - 2 + locationBuffer.count) % locationBuffer.count
    let lastIndex3 = (currentIndex - 3 + locationBuffer.count) % locationBuffer.count
    
    guard let lastValue1 = locationBuffer[lastIndex1],
          let lastValue2 = locationBuffer[lastIndex2],
          let lastValue3 = locationBuffer[lastIndex3] else {
        // Retorna false si alguno de los tres últimos valores es nil
        return false
    }
    
    // Crea un conjunto con los tres últimos valores
    let lastThreeValues: Set<String> = [lastValue1, lastValue2, lastValue3]

    // Recorre el resto del buffer y verifica si alguno coincide con los últimos tres valores
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
       currentIndex = (currentIndex + 1) % locationBuffer.count // Actualizar el índice de manera circular
       
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





