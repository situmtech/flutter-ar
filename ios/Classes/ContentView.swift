import SwiftUI
import Foundation

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

