import Cocoa
import FlutterMacOS
import NetworkExtension
import SystemExtensions

@main
class AppDelegate: FlutterAppDelegate {
  private static let extensionBundleID = "com.netbridge.netbridge.WGExtension"

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let window = mainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController
    else { return }

    let channel = FlutterMethodChannel(
      name: "netbridge/system_extension",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "activate":
        self?.activateSystemExtension()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Request activation of the WGExtension Packet Tunnel system extension.
  /// macOS prompts the user in System Settings on first activation.
  private func activateSystemExtension() {
    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier: Self.extensionBundleID,
      queue: DispatchQueue.main)
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

extension AppDelegate: OSSystemExtensionRequestDelegate {
  func request(
    _ request: OSSystemExtensionRequest,
    actionForReplacingExtension existing: OSSystemExtensionProperties,
    withExtension ext: OSSystemExtensionProperties
  ) -> OSSystemExtensionRequest.ReplacementAction {
    NSLog("NetBridge: replacing system extension %@ with %@", existing.bundleIdentifier, ext.bundleIdentifier)
    return .replace
  }

  func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    NSLog("NetBridge: system extension needs user approval (System Settings)")
  }

  func request(
    _ request: OSSystemExtensionRequest,
    didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    NSLog("NetBridge: system extension request finished: %d", result.rawValue)
  }

  func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
    NSLog("NetBridge: system extension request failed: %@", error.localizedDescription)
  }
}
