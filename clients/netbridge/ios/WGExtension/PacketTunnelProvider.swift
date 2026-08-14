// Packet Tunnel Provider scaffold for 网桥 VPN (iOS).
//
// This compiles as a Network Extension shell once the WGExtension target exists.
// For a real WireGuard tunnel, replace the body with WireGuardKit + WireGuardAdapter
// (see PacketTunnelProvider.WireGuardKit.swift.example and clients/netbridge/IMPL.md).

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
        // Ensure Flutter/plugin handed us a wg-quick config (same key as wireguard_flutter).
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
