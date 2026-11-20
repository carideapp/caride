import ActivityKit
import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@available(iOS 16.2, *)
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
  private var rideAlertsChannel: FlutterMethodChannel?
  private var pendingRideIntent: [String: String]?
  private var isDartRideAlertsReady = false
  private let declinedRideDefaultsKey = "caride_declined_ride_ids"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyAQPLeYuNmRW9OuPBK93sX5M01aebbiknI")
    GeneratedPluginRegistrant.register(with: self)

    UNUserNotificationCenter.current().delegate = self
    registerRideAlertCategory()

    if let remoteUserInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      let rideId = (remoteUserInfo["rideId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let type = (remoteUserInfo["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
      if !rideId.isEmpty {
        pendingRideIntent = [
          "rideId": rideId,
          "type": type.isEmpty ? "ride_request" : type,
          "action": "open",
        ]
      }
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.caride.app/live_activity",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleLiveActivityCall(call: call, result: result)
      }

      let alertsChannel = FlutterMethodChannel(
        name: "com.caride.app/ride_alerts",
        binaryMessenger: controller.binaryMessenger
      )
      alertsChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleRideAlertsCall(call: call, result: result)
      }
      rideAlertsChannel = alertsChannel
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleLiveActivityCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
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

  private func handleRideAlertsCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "consumePendingRideIntent":
      isDartRideAlertsReady = true
      let payload = pendingRideIntent
      pendingRideIntent = nil
      result(payload)

    case "cancelRideNotification":
      let rideId = (args["rideId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !rideId.isEmpty {
        removeRideNotifications(rideId: rideId)
      }
      result(true)

    case "markRideDeclined":
      let rideId = (args["rideId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !rideId.isEmpty {
        markRideDeclined(rideId)
        removeRideNotifications(rideId: rideId)
      }
      result(true)

    case "getDeclinedRideIds":
      result(getDeclinedRideIdsList())

    case "getIosNotificationReadiness":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        var info: [String: Any] = [
          "authorizationStatus": Self.authStatusString(settings.authorizationStatus),
          "soundSetting": Self.settingString(settings.soundSetting),
          "alertSetting": Self.settingString(settings.alertSetting),
          "lockScreenSetting": Self.settingString(settings.lockScreenSetting),
          "notificationCenterSetting": Self.settingString(settings.notificationCenterSetting),
        ]
        if #available(iOS 15.0, *) {
          info["timeSensitiveSetting"] = Self.settingString(settings.timeSensitiveSetting)
        }
        DispatchQueue.main.async {
          result(info)
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func registerRideAlertCategory() {
    let viewAction = UNNotificationAction(
      identifier: "VIEW_RIDE",
      title: "Open & Bid",
      options: [.foreground]
    )
    let declineAction = UNNotificationAction(
      identifier: "DECLINE_RIDE",
      title: "Decline",
      options: [.destructive]
    )
    let category = UNNotificationCategory(
      identifier: "INCOMING_RIDE_REQUEST",
      actions: [viewAction, declineAction],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    let type = (userInfo["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    if type == "ride_request" || type == "new_ride" || type == "ride_offer" {
      let rideId = (userInfo["rideId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !rideId.isEmpty && !isRideDeclined(rideId) {
        let payload = buildRidePayload(from: userInfo)
        rideAlertsChannel?.invokeMethod("onForegroundRideAlert", arguments: payload)
      }
      completionHandler([])
      return
    }
    if type == "ride_alert_cancel" {
      let rideId = (userInfo["rideId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !rideId.isEmpty {
        removeRideNotifications(rideId: rideId)
        rideAlertsChannel?.invokeMethod("onRideAlertCancelled", arguments: ["rideId": rideId])
      }
      completionHandler([])
      return
    }
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    let rideId = (userInfo["rideId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let type = (userInfo["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    let isRideRequest = type == "ride_request"
      || type == "new_ride"
      || type == "ride_offer"
      || response.notification.request.content.categoryIdentifier == "INCOMING_RIDE_REQUEST"

    if !rideId.isEmpty && isRideRequest {
      if response.actionIdentifier == "DECLINE_RIDE" {
        markRideDeclined(rideId)
        removeRideNotifications(rideId: rideId)
        if isDartRideAlertsReady {
          rideAlertsChannel?.invokeMethod("onRideNotificationDeclined", arguments: ["rideId": rideId])
        }
        completionHandler()
        return
      }
      if response.actionIdentifier == UNNotificationDefaultActionIdentifier || response.actionIdentifier == "VIEW_RIDE" {
        let payload: [String: String] = [
          "rideId": rideId,
          "type": type.isEmpty ? "ride_request" : type,
          "action": "open",
        ]
        if isDartRideAlertsReady, let channel = rideAlertsChannel {
          channel.invokeMethod("onRideNotificationTapped", arguments: payload)
        } else {
          pendingRideIntent = payload
        }
        completionHandler()
        return
      }
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    let type = (userInfo["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    if type == "ride_alert_cancel" {
      let rideId = (userInfo["rideId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !rideId.isEmpty {
        removeRideNotifications(rideId: rideId)
        if isDartRideAlertsReady {
          rideAlertsChannel?.invokeMethod("onRideAlertCancelled", arguments: ["rideId": rideId])
        }
      }
      completionHandler(.newData)
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }

  private func buildRidePayload(from userInfo: [AnyHashable: Any]) -> [String: Any] {
    var payload: [String: Any] = [
      "rideId": (userInfo["rideId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
      "type": (userInfo["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "ride_request",
    ]
    let keys = ["pickupLabel", "dropoffLabel", "rideType", "customerOffer", "paymentMethod", "distanceKm", "expiresAtMs"]
    for key in keys {
      if let value = userInfo[key] {
        payload[key] = value
      }
    }
    return payload
  }

  private func removeRideNotifications(rideId: String) {
    let center = UNUserNotificationCenter.current()
    let collapseId = "ride_\(rideId)"
    center.removeDeliveredNotifications(withIdentifiers: [collapseId, rideId])
    center.removePendingNotificationRequests(withIdentifiers: [collapseId, rideId])
    center.getDeliveredNotifications { notifications in
      let matching = notifications.compactMap { notif -> String? in
        let content = notif.request.content
        let idMatch = notif.request.identifier == collapseId
          || notif.request.identifier == rideId
          || content.threadIdentifier == collapseId
          || (content.userInfo["rideId"] as? String) == rideId
        return idMatch ? notif.request.identifier : nil
      }
      if !matching.isEmpty {
        center.removeDeliveredNotifications(withIdentifiers: matching)
      }
    }
  }

  private func getDeclinedRideIdsList() -> [String] {
    UserDefaults.standard.stringArray(forKey: declinedRideDefaultsKey) ?? []
  }

  private func isRideDeclined(_ rideId: String) -> Bool {
    getDeclinedRideIdsList().contains(rideId)
  }

  private func markRideDeclined(_ rideId: String) {
    var ids = getDeclinedRideIdsList()
    if ids.contains(rideId) { return }
    ids.append(rideId)
    if ids.count > 50 {
      ids.removeFirst(ids.count - 50)
    }
    UserDefaults.standard.set(ids, forKey: declinedRideDefaultsKey)
  }

  private static func authStatusString(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unknown"
    }
  }

  private static func settingString(_ setting: UNNotificationSetting) -> String {
    switch setting {
    case .enabled: return "enabled"
    case .disabled: return "disabled"
    case .notSupported: return "notSupported"
    @unknown default: return "unknown"
    }
  }
}
