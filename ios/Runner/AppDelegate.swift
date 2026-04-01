import UIKit
import Flutter
import GoogleMaps
import Firebase
import FBSDKCoreKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GMSServices.provideAPIKey("AIzaSyCaCSJ0BZItSyXqBv8vpD1N4WBffJeKhLQ")

    // Set notification delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)

    // Live Activity MethodChannel
    let controller = window?.rootViewController as! FlutterViewController
    let liveActivityChannel = FlutterMethodChannel(
      name: "com.hamdiesolutions.waddi/live_activity",
      binaryMessenger: controller.binaryMessenger
    )
    liveActivityChannel.setMethodCallHandler { (call, result) in
      LiveActivityManager.shared.handle(call, result: result)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
