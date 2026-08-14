import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Desktop master–detail breakpoint is 900 logical px wide.
    self.minSize = NSSize(width: 900, height: 560)
    if self.frame.width < 1100 || self.frame.height < 720 {
      self.setContentSize(NSSize(width: 1100, height: 720))
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
