import Cocoa
import FlutterMacOS
import NetworkExtension
import Obfs2bridge
import SystemExtensions

@main
class AppDelegate: FlutterAppDelegate {
  private static let extensionBundleID = "com.netbridge.netbridge.WGExtension"

  /// Flutter results waiting for the in-flight activation request to settle.
  /// The Dart side awaits `activate`, so `startVpn` never races an unfinished
  /// activation (the "two clicks to connect" bug).
  private var pendingActivationResults: [FlutterResult] = []
  private var activeRequest: OSSystemExtensionRequest?
  private var activationTimeout: DispatchWorkItem?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("NetBridge: applicationDidFinishLaunching (window=%d)", mainFlutterWindow != nil ? 1 : 0)
    registerSystemExtensionChannel()
  }

  /// Registers the activation channel. Retried after a short delay when the
  /// Flutter window/engine is not ready yet at launch time.
  private func registerSystemExtensionChannel() {
    guard let window = mainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController
    else {
      NSLog("NetBridge: window not ready — retry channel registration in 2s")
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
        self?.registerSystemExtensionChannel()
      }
      return
    }

    let channel = FlutterMethodChannel(
      name: "netbridge/system_extension",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "activate":
        NSLog("NetBridge: activate requested from Dart")
        self?.activateSystemExtension(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    NSLog("NetBridge: system_extension channel registered")

    // In-process obfs2 transport bridge (gomobile xcframework).
    let obfs2Channel = FlutterMethodChannel(
      name: "netbridge/obfs2",
      binaryMessenger: controller.engine.binaryMessenger)
    obfs2Channel.setMethodCallHandler { call, result in
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
          NSLog("NetBridge: obfs2 bridge started (in-process)")
          result(true)
        } else {
          result(FlutterError(
            code: "obfs2_start_failed",
            message: err?.localizedDescription ?? "unknown error",
            details: nil))
        }
      case "stop":
        Obfs2bridgeStop()
        NSLog("NetBridge: obfs2 bridge stopped")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    NSLog("NetBridge: obfs2 channel registered")
  }

  /// Request activation of the WGExtension Packet Tunnel system extension.
  /// Settles `result` when the request completes, fails, or times out
  /// (120s — covers the System Settings approval round-trip).
  private func activateSystemExtension(result: @escaping FlutterResult) {
    pendingActivationResults.append(result)

    // A request is already in flight (rapid re-click); its completion
    // settles all pending results together.
    guard activeRequest == nil else { return }

    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier: Self.extensionBundleID,
      queue: DispatchQueue.main)
    request.delegate = self
    activeRequest = request
    OSSystemExtensionManager.shared.submitRequest(request)

    let timeout = DispatchWorkItem { [weak self] in
      NSLog("NetBridge: system extension activation timed out")
      self?.settleActivation("timeout")
    }
    activationTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: timeout)
  }

  private func settleActivation(_ value: String) {
    activationTimeout?.cancel()
    activationTimeout = nil
    activeRequest = nil
    let results = pendingActivationResults
    pendingActivationResults.removeAll()
    for result in results {
      result(value)
    }
  }

  private func failActivation(_ error: Error) {
    activationTimeout?.cancel()
    activationTimeout = nil
    activeRequest = nil
    let results = pendingActivationResults
    pendingActivationResults.removeAll()
    for result in results {
      result(FlutterError(
        code: "activation_failed",
        message: error.localizedDescription,
        details: nil))
    }
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
    // Deep-link to the Login Items & Extensions pane so the user can approve.
    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
      NSWorkspace.shared.open(url)
    }
  }

  func request(
    _ request: OSSystemExtensionRequest,
    didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    guard request === activeRequest else { return }
    NSLog("NetBridge: system extension request finished: %d", result.rawValue)
    settleActivation(result == .willCompleteAfterReboot ? "willCompleteAfterReboot" : "completed")
  }

  func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
    guard request === activeRequest else { return }
    NSLog("NetBridge: system extension request failed: %@", error.localizedDescription)
    failActivation(error)
  }
}
