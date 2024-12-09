import Foundation
import simd

struct LocationCoordinates {
    var x: Double
    var y: Double
    var yaw: Double
    var timestamp: TimeInterval
    var floorIdentifier: String = ""
    var accuracy: Int64 = 0
    var hasBearing: Bool = true

    static func -(lhs: LocationCoordinates, rhs: LocationCoordinates) -> LocationCoordinates {
        return LocationCoordinates(
            x: lhs.x - rhs.x,
            y: lhs.y - rhs.y,
            yaw: lhs.yawAdd(-rhs.yaw),
            timestamp: lhs.timestamp - rhs.timestamp,
            floorIdentifier: lhs.floorIdentifier
        )
    }

    func distanceTo(_ other: LocationCoordinates) -> Double {
        return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }

    func rotate(by angle: Double) -> LocationCoordinates {
        let cosA = cos(angle)
        let sinA = sin(angle)
        return LocationCoordinates(
            x: x * cosA - y * sinA,
            y: x * sinA + y * cosA,
            yaw: yawAdd(angle),
            timestamp: timestamp,
            floorIdentifier: floorIdentifier
        )
    }

    func angularDistanceTo(_ other: LocationCoordinates) -> Double {
        var angleDifference = yaw - other.yaw
        angleDifference = normalizeAngle(angleDifference)
        return abs(angleDifference)
    }

    func yawAdd(_ angle: Double) -> Double {
        var sum = yaw + angle
        sum = normalizeAngle(sum)
        return sum
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * Double.pi)
        if normalizedAngle < -Double.pi {
            normalizedAngle += 2 * Double.pi
        } else if normalizedAngle > Double.pi {
            normalizedAngle -= 2 * Double.pi
        }
        return normalizedAngle
    }

    var description: String {
        return "LocationCoordinates(x: \(x), y: \(y), yaw: \(yaw), timestamp: \(timestamp))"
    }
}
