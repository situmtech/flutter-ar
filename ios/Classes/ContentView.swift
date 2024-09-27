import SwiftUI
import Foundation
import Combine



extension Notification.Name {
    static let resetCoordinatorFlags = Notification.Name("resetCoordinatorFlags")
}


@available(iOS 13.0, *)
struct ContentView: View {
    @ObservedObject private var locationManager = LocationManager()
    @State private var poisMap: [String: Any]
    @State private var width: Double = 0.0
    @State private var showAlert = false

    init(poisMap: [String: Any]) {
        _poisMap = State(initialValue: poisMap)
    }

    var body: some View {
        ARViewContainer(poisMap: $poisMap, locationManager: locationManager, width: width)
            .edgesIgnoringSafeArea(.all)
            .onReceive(NotificationCenter.default.publisher(for: .poisUpdated)) { notification in
                if let poisMap = notification.userInfo?["poisMap"] as? [String: Any] {
                    self.poisMap = poisMap
                }
                if let width = notification.userInfo?["width"] as? Double {
                    self.width = width
                } else {
                    print("Failed to cast POIs map. UserInfo: \(String(describing: notification.userInfo))")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .buttonPressedNotification)) { _ in
                self.showAlert = true
                NotificationCenter.default.post(name: .resetCoordinatorFlags, object: nil)
            }
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
