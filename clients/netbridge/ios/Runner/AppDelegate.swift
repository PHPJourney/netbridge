import Flutter
import UIKit
import Obfs2bridge

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      registerObfs2Channel(controller)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// In-process obfs2 transport bridge (gomobile xcframework) — same channel
  /// contract as macOS/Android.
  private func registerObfs2Channel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "netbridge/obfs2",
      binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        guard let args = call.arguments as? [String: Any] else {
          result(false)
          return
        }
        let serverAddrs = args["serverAddrs"] as? String ?? ""
        let psk = args["psk"] as? String ?? ""
        let localUdp = Int(args["localUdp"] as? Int ?? 51822)
        let insecure = args["insecure"] as? Bool ?? false
        let channels = Int(args["channels"] as? Int ?? 4)
        var err: NSError?
        let ok = Obfs2bridgeStart(serverAddrs, psk, localUdp, insecure, channels, &err)
        if ok {
          NSLog("NetBridge: obfs2 bridge started (in-process, iOS)")
          result(true)
        } else {
          result(FlutterError(
            code: "obfs2_start_failed",
            message: err?.localizedDescription ?? "unknown error",
            details: nil))
        }
      case "stop":
        Obfs2bridgeStop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
