import UIKit
import Flutter
import GoogleMaps
import Firebase
import FBSDKCoreKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  /// Shared engine owned by the app and attached to the window scene by
  /// `SceneDelegate`. Under the UIScene lifecycle the app delegate no longer
  /// owns a window, so the engine has to outlive any single scene.
  static let flutterEngine = FlutterEngine(name: "waddy.main")

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

    AppDelegate.flutterEngine.run()
    GeneratedPluginRegistrant.register(with: AppDelegate.flutterEngine)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}
