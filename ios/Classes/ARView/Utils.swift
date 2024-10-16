import Foundation
import ARKit
import RealityKit
import CoreLocation
import MetalKit
import SitumSDK

@available(iOS 15.0, *)
    func parsePois(pois: [SITPOI]) -> [[String: Any]] {
        var poisMap: [[String: Any]] = []

        for poi in pois {
            // Llamar a la función position() para obtener el valor de SITPoint
            let position = poi.position()
            let icon = poi.category.iconURL
            print("ICON URL:   ", icon)
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
                    "iconUrl": icon
                ]
                poisMap.append(poiDict)
            } else {
                print("Situm> Cartesian coordinate not available for POI: \(poi.name)")
            }
        }

        return poisMap
    }


@available(iOS 15.0, *)
    func createSphereEntity(radius: Float, color: UIColor, transparency: Float) -> ModelEntity {
        let sphereMesh = MeshResource.generateSphere(radius: radius)

        // Descomponer el color en componentes de tono, saturación y brillo
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Reducir la saturación del color
        let desaturatedColor = UIColor(hue: hue, saturation: saturation * 0.5, brightness: brightness, alpha: alpha * CGFloat(transparency))

        // Crear el material con transparencia y color desaturado
        let material = SimpleMaterial(color: desaturatedColor, isMetallic: false)

        let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])

        return sphereEntity
    }

@available(iOS 15.0, *)
func createDiskEntity(radius: Float, thickness: Float, color: UIColor) -> ModelEntity {
    // Generar la malla del disco (plano)
    let diskMesh = MeshResource.generatePlane(width: 2 * radius, depth: 2 * radius, cornerRadius: radius)

    // Crear el material para el disco
    var material = SimpleMaterial()
    material.color = .init(tint: color, texture: nil)

    // Crear la entidad del disco
    let diskEntity = ModelEntity(mesh: diskMesh, materials: [material])

    // Rotar el disco para que esté en vertical
    diskEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))

    // Ajustar el grosor (y) del disco simulando una pequeña separación entre las dos caras
    let frontEntity = ModelEntity(mesh: diskMesh, materials: [material])
    frontEntity.setParent(diskEntity)
    frontEntity.position = SIMD3(0, thickness / 2, 0)

    let backEntity = ModelEntity(mesh: diskMesh, materials: [material])
    backEntity.setParent(diskEntity)
    backEntity.position = SIMD3(0, -thickness / 200, 0)

    return diskEntity
}



    
@available(iOS 15.0, *)
    func createTextEntity(text: String, position: SIMD3<Float>) -> ModelEntity {
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
        
        return textEntity
    }
