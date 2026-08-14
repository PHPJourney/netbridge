// Packet Tunnel Provider scaffold for 网桥 VPN (macOS).
//
// See ios/WGExtension for the same contract. Full WireGuardKit body:
// PacketTunnelProvider.WireGuardKit.swift.example + IMPL.md.

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
        log("startTunnel — WireGuardKit not linked yet (scaffold)")
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
        // Known macOS Network Extension quirk: process may need explicit exit after stop.
        // Uncomment only after a real tunnel is linked and you observe hung extensions:
        // exit(0)
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }
}
