import Foundation
import ARKit
import RealityKit
import CoreLocation
import MetalKit
import UIKit
import CoreGraphics
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
func createTexturedDisk(with image: UIImage, diameter: Float) -> ModelEntity? {
    // Crear el disco en RealityKit con el diámetro especificado
    let diskMesh = MeshResource.generatePlane(width: diameter, depth: diameter)
    let diskEntity = ModelEntity(mesh: diskMesh)
    
    // Crear la textura desde la imagen circular
    guard let cgImage = image.cgImage,
          let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) else {
        print("Error: No se pudo generar la textura desde la imagen.")
        return nil
    }
    
    // Crear un material para aplicar la textura en el disco
    var texturedMaterial = UnlitMaterial()
     texturedMaterial.baseColor = .texture(texture)
     texturedMaterial.opacityThreshold = 0.5

    
    // Asignar el material texturizado al disco
    diskEntity.model?.materials = [texturedMaterial]
    
    return diskEntity
}


@available(iOS 15.0, *)
func replaceTextureOnCylinder(url: URL, completion: @escaping (Entity?) -> Void) {
    
    let modelName = "cylinder.usdz"

    do {
        // Cargar el modelo como una Entity
        let entity = try Entity.load(named: modelName)

        // Cargar la nueva textura desde la URL
        ImageCacheManager.shared.loadImage(from: url) { image in
            guard let image = image else {
                print("Error al cargar la imagen para la textura.")
                completion(nil)
                return
            }

            // Convertir la UIImage a CGImage
            guard let cgImage = image.cgImage else {
                print("Error al convertir UIImage a CGImage.")
                completion(nil)
                return
            }

            // Generar la textura desde el CGImage
            let options = TextureResource.CreateOptions(semantic: .color)
            guard let texture = try? TextureResource.generate(from: cgImage, options: options) else {
                print("Error al generar la textura desde CGImage.")
                completion(nil)
                return
            }
            // Aplicar la textura a todos los nodos ModelEntity
            applyTextureToModelEntities(in: entity, texture: texture)

            completion(entity)
        }
    } catch {
        print("Error al cargar el modelo: \(error.localizedDescription)")
        completion(nil)
    }
}
@available(iOS 15.0, *)
func applyTextureToModelEntities(in entity: Entity, texture: TextureResource) {
    // Si la entidad es un ModelEntity, aplicar la textura
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

    // Buscar recursivamente en los hijos
    for child in entity.children {
        applyTextureToModelEntities(in: child, texture: texture)
    }
}



/*@available(iOS 15.0, *)
func addPointLightToScene(at position: SIMD3<Float>, arView: ARView) {
    let lightEntity = PointLight()
    lightEntity.light.intensity = 15000  // Ajusta según el nivel de brillo que desees
    lightEntity.light.color = .white
    
    let lightAnchor = AnchorEntity(world: position)
    lightAnchor.addChild(lightEntity)
    arView.scene.addAnchor(lightAnchor)
}*/

@available(iOS 15.0, *)
func createTextEntity(text: String, poiPosition: SIMD3<Float>, arView: ARView) -> ModelEntity {
    // Generar el texto principal
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

    // Generar el texto para el borde
    let borderMesh = MeshResource.generateText(
        text,
        extrusionDepth: 0.025, // Extrusión ligeramente mayor
        font: .systemFont(ofSize: 1.2),
        containerFrame: .zero,
        alignment: .center,
        lineBreakMode: .byWordWrapping
    )
    let borderMaterial = SimpleMaterial(color: .black, isMetallic: false)
    let borderTextEntity = ModelEntity(mesh: borderMesh, materials: [borderMaterial])
    borderTextEntity.scale = SIMD3<Float>(0.355, 0.355, 0.355) // Misma escala que el texto principal
    borderTextEntity.position = SIMD3<Float>(0, 0, -0.002) // Ajustar ligeramente hacia atrás

    // Contenedor para mantener ambos textos juntos
    let containerEntity = ModelEntity()
    containerEntity.addChild(borderTextEntity) // Añadir el texto del borde primero
    containerEntity.addChild(mainTextEntity)  // Añadir el texto principal

    // Posicionar el contenedor directamente encima del POI
    containerEntity.position = SIMD3<Float>(poiPosition.x, poiPosition.y + 1.05, poiPosition.z)

    // Centrar el texto en el eje X
    let bounds = containerEntity.visualBounds(relativeTo: nil)
    let textWidth = bounds.extents.x
    containerEntity.position.x -= textWidth / 2.0

    return containerEntity
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

func updatePOIOrientationToCamera(arView: ARView) {
    guard let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity else {
        return
    }

    // Obtener la posición de la cámara
    let cameraPosition = arView.cameraTransform.translation

    for child in fixedPOIAnchor.children {
        // Verificar si la entidad es un contenedor de POI
        if child.name.starts(with: "poiContainer_") {
            // Calcular la posición del POI
            let poiPosition = child.position(relativeTo: nil)

            // Orientar el POI hacia la cámara
            if let poiEntity = child.children.first(where: { $0.name.starts(with: "poi_") }) {
                poiEntity.look(at: cameraPosition, from: poiPosition, relativeTo: nil)
            }

            // Ajustar y centrar el texto
            if let textEntity = child.children.first(where: { $0.name.starts(with: "text_") }) {
                // Mantener el texto por encima del POI
                textEntity.position = SIMD3<Float>(0, 1.05, 0)

                // Centrar el texto respecto al POI
                let bounds = textEntity.visualBounds(relativeTo: textEntity.parent)
                let textWidth = bounds.extents.x
                textEntity.position.x -= bounds.center.x // Centrar horizontalmente usando el centro del texto
                textEntity.position.z -= bounds.center.z // Asegurar el centrado en profundidad

                // Orientar el texto hacia la cámara
                textEntity.look(at: cameraPosition, from: textEntity.position(relativeTo: nil), relativeTo: nil)

                // Evitar que el texto se invierta
                let textRotationCorrection = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                textEntity.orientation = simd_mul(textEntity.orientation, textRotationCorrection)
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

        UIView.animate(withDuration: 0.5, animations: {
            toastContainer.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut, animations: {
                toastContainer.alpha = 0.0
            }) { _ in
                toastContainer.removeFromSuperview()
            }
        }
    }
}


