import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct RideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var etaMinutes: Int
    }

    var rideId: String
    var pickup: String
    var dropoff: String
    var driverName: String
    var vehicleInfo: String
}

