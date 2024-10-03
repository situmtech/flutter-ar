import SwiftUI
import RealityKit
import ARKit



@available(iOS 13.0, *)
struct ARViewContainer: UIViewRepresentable {
    @Binding var poisMap: [String: Any]
    @ObservedObject var locationManager: LocationManager
    var width: Double
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.cameraMode = .ar
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        configuration.planeDetection = []
        arView.session.run(configuration)
        
        let yawLabel = UILabel()
        yawLabel.frame = CGRect(x: 20, y: 20, width: 200, height: 50)
        yawLabel.textColor = .white
        yawLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        yawLabel.textAlignment = .center
        yawLabel.text = "Yaw: 0.0°"
        // Añadir la etiqueta al ARView
        arView.addSubview(yawLabel)
        // Guardar referencias para actualizar el yaw
        context.coordinator.arView = arView
        context.coordinator.yawLabel = yawLabel
        context.coordinator.setupFixedAnchor()
        // Establecer el delegado de la sesión para recibir actualizaciones
        arView.session.delegate = context.coordinator
        

       /* let arrowAnchor = createArrowAnchor()
        arView.scene.anchors.append(arrowAnchor)
*/
        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator

  //      context.coordinator.arrowAnchor = arrowAnchor
       

        NotificationCenter.default.addObserver(forName: .locationUpdated, object: nil, queue: .main) { notification in
            context.coordinator.handleLocationUpdate(notification)
        }
        
        NotificationCenter.default.addObserver(forName: .updatePointsList, object: nil, queue: .main) { notification in
            context.coordinator.handlePointUpdate(notification)
        }

        NotificationCenter.default.addObserver(forName: .resetCoordinatorFlags, object: nil, queue: .main) { _ in
            context.coordinator.resetFlags()
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateArrowPositionAndDirection()
        context.coordinator.updateTextOrientation()

        if !context.coordinator.didUpdatePOIs && !poisMap.isEmpty && width > 0 {
            context.coordinator.updatePOIs(poisMap: poisMap, width: width)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(locationManager: locationManager)
    }

    func createArrowAnchor() -> AnchorEntity {
        let anchor = AnchorEntity()

        do {
            let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            arrowEntity.scale = SIMD3<Float>(0.05, 0.05, 0.05)
            arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)
            anchor.addChild(arrowEntity)
        } catch {
            print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
        }

        return anchor
    }
}



/*
import SwiftUI

 import RealityKit

 import ARKit

 import Combine
 
struct ContentView: View {

     var body: some View {

         ARViewContainer().edgesIgnoringSafeArea(.all)

     }

 }
 
struct ARViewContainer: UIViewRepresentable {

     class Coordinator: NSObject, ARSessionDelegate {

         var arView: ARView?

         var yawLabel: UILabel?

         var cancellable: AnyCancellable?

         func session(_ session: ARSession, didUpdate frame: ARFrame) {

             // Obtener el yaw de la cámara respecto al norte

             if let yaw = getCameraYawRespectToNorth() {

                 // Actualizar la etiqueta con el valor del yaw

                 DispatchQueue.main.async {

                     self.yawLabel?.text = "Yaw: \(yaw * (180.0 / .pi))°"

                 }

             }

         }

         func getCameraYawRespectToNorth() -> Float? {
             return arView?.session.currentFrame?.camera.eulerAngles.y
   
         }

     }

     func makeUIView(context: Context) -> ARView {

         let arView = ARView(frame: .zero)

         arView.cameraMode = .ar

         arView.automaticallyConfigureSession = false
 
        // Configuración de la sesión con gravityAndHeading

         let config = ARWorldTrackingConfiguration()

         config.worldAlignment = .gravity

         arView.session.run(config)

         // Crear y añadir la etiqueta para mostrar el yaw

         let yawLabel = UILabel()

         yawLabel.frame = CGRect(x: 20, y: 50, width: 200, height: 50)

         yawLabel.textColor = .white

         yawLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)

         yawLabel.textAlignment = .center

         yawLabel.text = "Yaw: 0.0°"

         // Añadir la etiqueta al ARView

         arView.addSubview(yawLabel)

         // Guardar referencias para actualizar el yaw

         context.coordinator.arView = arView

         context.coordinator.yawLabel = yawLabel

         // Establecer el delegado de la sesión para recibir actualizaciones

         arView.session.delegate = context.coordinator

         return arView

     }

     func updateUIView(_ uiView: ARView, context: Context) {

         // Actualización de la vista

     }

     func makeCoordinator() -> Coordinator {

         return Coordinator()

     }

 }
 
*/
