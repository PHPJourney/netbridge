// Entry point for the WGExtension Packet Tunnel system extension.
// System extensions are standalone executables (unlike app extensions),
// so they need an explicit main that hands control to the NE framework.
import Foundation
import NetworkExtension

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}
dispatchMain()
