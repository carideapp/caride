import ActivityKit
import Flutter
import GoogleMaps
import UIKit

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

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var currentActivityId: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyAQPLeYuNmRW9OuPBK93sX5M01aebbiknI")
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.caride.app/live_activity",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleLiveActivityCall(call: call, result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleLiveActivityCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }

    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "startRideActivity":
      let rideId = args["rideId"] as? String ?? ""
      let status = args["status"] as? String ?? "Driver assigned"
      let driverName = args["driverName"] as? String ?? "Driver"
      let vehicleInfo = args["vehicleInfo"] as? String ?? ""
      let etaMinutes = args["etaMinutes"] as? Int ?? 5
      let pickup = args["pickup"] as? String ?? ""
      let dropoff = args["dropoff"] as? String ?? ""

      let attributes = RideActivityAttributes(
        rideId: rideId,
        pickup: pickup,
        dropoff: dropoff,
        driverName: driverName,
        vehicleInfo: vehicleInfo
      )
      let state = RideActivityAttributes.ContentState(
        status: status,
        etaMinutes: etaMinutes
      )

      do {
        let activity = try Activity.request(
          attributes: attributes,
          content: .init(state: state, staleDate: nil),
          pushType: nil
        )
        currentActivityId = activity.id
        result(activity.id)
      } catch {
        result(FlutterError(code: "LIVE_ACTIVITY_ERROR", message: error.localizedDescription, details: nil))
      }

    case "updateRideActivity":
      let status = args["status"] as? String ?? "In progress"
      let etaMinutes = args["etaMinutes"] as? Int ?? 1
      let state = RideActivityAttributes.ContentState(
        status: status,
        etaMinutes: etaMinutes
      )
      Task {
        for activity in Activity<RideActivityAttributes>.activities {
          await activity.update(.init(state: state, staleDate: nil))
        }
      }
      result(nil)

    case "endRideActivity":
      Task {
        for activity in Activity<RideActivityAttributes>.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
      }
      currentActivityId = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
