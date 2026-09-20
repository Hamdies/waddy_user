import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let controller = FlutterViewController(
      engine: AppDelegate.flutterEngine,
      nibName: nil,
      bundle: nil
    )

    // Live Activity MethodChannel
    let liveActivityChannel = FlutterMethodChannel(
      name: "com.hamdiesolutions.waddi/live_activity",
      binaryMessenger: controller.binaryMessenger
    )
    liveActivityChannel.setMethodCallHandler { (call, result) in
      LiveActivityManager.shared.handle(call, result: result)
    }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = controller
    self.window = window
    window.makeKeyAndVisible()
  }
}
