// Packet Tunnel Provider for 网桥 VPN (macOS).
// WGExtension is embedded in Runner. WireGuardKit SPM (wireguard-apple) was not
// vendored here: passepartoutvpn fork is gone (404); official Package.swift needs
 // tools-version 5.5+ and a Go build for WireGuardKitGo. Until WireGuardKit is
 // linked, startTunnel returns wireGuardKitNotLinked after validating wgQuickConfig.
 // Full body: apple/PacketTunnelProvider.WireGuardKit.swift.example — see IMPL.md.

import Foundation
import NetworkExtension

enum PacketTunnelProviderError: Error {
    case wireGuardKitNotLinked
    case invalidProtocolConfiguration
}

class PacketTunnelProvider: NEPacketTunnelProvider {
    func log(_ message: String) {
        NSLog("NetBridge WGExtension: %@", message)
    }

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        log("startTunnel — WireGuardKit not linked yet (embedded scaffold)")
        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              providerConfiguration["wgQuickConfig"] as? String != nil
        else {
            completionHandler(PacketTunnelProviderError.invalidProtocolConfiguration)
            return
        }
        completionHandler(PacketTunnelProviderError.wireGuardKitNotLinked)
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        log("stopTunnel reason=\(reason.rawValue)")
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }
}
