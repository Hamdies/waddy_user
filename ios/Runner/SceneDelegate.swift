import UIKit
import Flutter

/// Plugins (app_links, …) receive scene events only through a
/// `FlutterPluginSceneLifeCycleDelegate`. A plain `UIWindowSceneDelegate`
/// swallows them, which silently dropped every opened URL — `waddy://` links
/// and the Live Activity tap alike — so each callback is forwarded here.
class SceneDelegate: UIResponder, UIWindowSceneDelegate, FlutterSceneLifeCycleProvider {

  var window: UIWindow?

  let sceneLifeCycleDelegate = FlutterPluginSceneLifeCycleDelegate()

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

    // The engine is app-owned, so register it before handing over the launch
    // options: a cold start from a link carries the URL in them.
    sceneLifeCycleDelegate.registerSceneLifeCycle(with: AppDelegate.flutterEngine)
    sceneLifeCycleDelegate.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidDisconnect(scene)
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillEnterForeground(scene)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidBecomeActive(scene)
  }

  func sceneWillResignActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillResignActive(scene)
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidEnterBackground(scene)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    sceneLifeCycleDelegate.scene(scene, openURLContexts: URLContexts)
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    sceneLifeCycleDelegate.scene(scene, continue: userActivity)
  }

  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    sceneLifeCycleDelegate.windowScene(
      windowScene,
      performActionFor: shortcutItem,
      completionHandler: completionHandler
    )
  }
}
