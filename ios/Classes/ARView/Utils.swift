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
    // Entidad principal que contendrá todos los planos para formar el disco grueso
    let thickCircularEntity = ModelEntity()
    let thickness = Float(0.1)
    let segments = 10

    // Crear textura a partir de la imagen original
    guard let cgImage = image.cgImage else {
        print("Error: No se pudo convertir UIImage a CGImage.")
        return ModelEntity()
    }
    
    // Voltear la imagen horizontalmente y crear la textura
    let flippedImage = image.withHorizontallyFlippedOrientation()
    guard let flippedCGImage = flippedImage.cgImage else {
        print("Error: No se pudo convertir UIImage flípeada a CGImage.")
        return ModelEntity()
    }

    // Generar las texturas desde las imágenes original y volteada
    guard let originalTexture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)),
          let flippedTexture = try? TextureResource.generate(from: flippedCGImage, options: .init(semantic: .color)) else {
        print("Error: No se pudo generar la textura desde las imágenes.")
        return ModelEntity()
    }

    // Crear materiales para ambas texturas
    var originalMaterial = UnlitMaterial()
    originalMaterial.baseColor = .texture(originalTexture)
    originalMaterial.opacityThreshold = 0.5  // Respetar la transparencia del PNG

    var flippedMaterial = UnlitMaterial()
    flippedMaterial.baseColor = .texture(flippedTexture)
    flippedMaterial.opacityThreshold = 0.5  // Respetar la transparencia del PNG

    // Calcular la distancia entre cada plano para crear el grosor
    let segmentSpacing = thickness / Float(segments - 1)

    // Generar y posicionar cada plano para crear el efecto de grosor
    for i in 0..<segments {
        let planeMesh = MeshResource.generatePlane(width: 2 * radius, depth: 2 * radius)
        let frontPlaneEntity = ModelEntity(mesh: planeMesh, materials: [originalMaterial])
        let backPlaneEntity = ModelEntity(mesh: planeMesh, materials: [flippedMaterial])
        
        // Rotar el plano para que esté en posición vertical
        frontPlaneEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        
        // Rotar el plano trasero 180 grados en Z para evitar que la imagen aparezca invertida
        backPlaneEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 0, 1))

        // Posicionar cada plano a lo largo del eje Z para crear el grosor
        let offset = Float(i) * segmentSpacing - (thickness / 2)
        frontPlaneEntity.position = SIMD3(0, 0, offset)
        backPlaneEntity.position = SIMD3(0, 0, offset)
        
        // Agregar los planos a la entidad principal
        thickCircularEntity.addChild(frontPlaneEntity)
        thickCircularEntity.addChild(backPlaneEntity)
    }

    return thickCircularEntity
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
func createTextEntity(text: String, position: SIMD3<Float>, arView: ARView) -> ModelEntity {
    let mesh = MeshResource.generateText(
        text,
        extrusionDepth: 0.02,
        font: .systemFont(ofSize: 1.3),
        containerFrame: .zero,
        alignment: .center,
        lineBreakMode: .byWordWrapping
    )
    
    let material = SimpleMaterial(color: .white, isMetallic: false)
    let textEntity = ModelEntity(mesh: mesh, materials: [material])
    
    textEntity.scale = SIMD3<Float>(0.3, 0.3, 0.3)
    textEntity.position = SIMD3<Float>(position.x, position.y + 0.5, position.z)
    
    
   // Actualizar la orientación del texto en relación con la cámara sin voltearse
    arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
        let cameraTransform = arView.cameraTransform
        let cameraForward = cameraTransform.matrix.columns.2 // Dirección hacia adelante de la cámara
        
        // Obtener la dirección que la entidad debe mirar sin voltear en el eje Y
        let newForward = normalize(SIMD3<Float>(-cameraForward.x, 0, -cameraForward.z))
        let rotation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: newForward)
        textEntity.orientation = rotation
    }
    
    return textEntity
}


func rotateIconPoi(arView: ARView){
    
    if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
        for child in fixedPOIAnchor.children {
            if let poiEntity = child as? ModelEntity, poiEntity.name.starts(with: "poi_") {
               

                var currentRotation = poiEntity.orientation
                                    
                // Definir una rotación incremental en el eje Y (continua)
                let rotationAngle: Float = .pi / 360 // Un pequeño ángulo en cada actualización (1 grado)
                let rotationIncrement = simd_quatf(angle: rotationAngle, axis: SIMD3<Float>(0, 1, 0))
                
                // Aplicar la rotación incremental a la entidad
                currentRotation = simd_mul(currentRotation, rotationIncrement)
                poiEntity.orientation = currentRotation
            }
        }
    }
    
}

func updateTextOrientation(arView: ARView) {       

        if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
            for child in fixedPOIAnchor.children {
                if let textEntity = child as? ModelEntity, textEntity.name.starts(with: "text_") {
                    let cameraPosition = arView.cameraTransform.translation

                    textEntity.look(at: cameraPosition, from: textEntity.position, relativeTo: nil)
                    textEntity.orientation = simd_mul(
                        textEntity.orientation,
                        simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                    )
                }
            }
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



