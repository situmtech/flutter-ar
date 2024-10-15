import Foundation
import SitumSDK

func parsePointsRoute(routeData: String) -> [RoutePoint]{
    
    let points = routeData.split(separator: ",") // Divide la cadena por comas
        var routePoints: [RoutePoint] = []
        
        // Procesa los puntos
        for point in points {
            // Extraer las propiedades de cada punto (simplificado)
            let floorIdentifier = extractValue(from: point, key: "floorIdentifier:")
            let cartesianX = extractCoordinate(from: point, key: "x:")
            let cartesianY = extractCoordinate(from: point, key: "y:")
            
            // Crear un RoutePoint
            let routePoint = RoutePoint(                
                buildingIdentifier: buildingIdentifier,
                floorIdentifier: floorIdentifier,
                cartesianCoordinates: (x: cartesianX, y: cartesianY),            )
            
            routePoints.append(routePoint)
        }
        
        return routePoints
    
}

func extractValue(from text: Substring, key: String) -> String {
    if let range = text.range(of: key) {
        let value = text[range.upperBound...].split(separator: " ").first ?? ""
        return String(value)
    }
    return ""
}


func parsePois(pois: [SITPOI]) -> [[String: Any]] {
    var poisMap: [[String: Any]] = []

    for poi in pois {
        // Llamar a la función position() para obtener el valor de SITPoint
        let position = poi.position()
        
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
                ]
            ]
            poisMap.append(poiDict)
        } else {
            print("Situm> Cartesian coordinate not available for POI: \(poi.name)")
        }
    }

    return poisMap
}




