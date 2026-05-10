import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var isQuitting = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let minimumSize = NSSize(width: 980, height: 680)
    let preferredSize = NSSize(width: 1220, height: 780)
    let visibleFrame = NSScreen.main?.visibleFrame ?? self.frame
    let openingSize = NSSize(
      width: min(preferredSize.width, max(minimumSize.width, visibleFrame.width * 0.92)),
      height: min(preferredSize.height, max(minimumSize.height, visibleFrame.height * 0.9))
    )
    let windowFrame = NSRect(
      x: visibleFrame.midX - openingSize.width / 2,
      y: visibleFrame.midY - openingSize.height / 2,
      width: openingSize.width,
      height: openingSize.height
    )

    self.minSize = minimumSize
    self.setFrameAutosaveName("MusicFlowMainWindow")
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func close() {
    if isQuitting {
      super.close()
      return
    }

    let alert = NSAlert()
    alert.messageText = "退出确认"
    alert.informativeText = "选择退出方式："
    alert.addButton(withTitle: "取消")
    alert.addButton(withTitle: "后台运行")
    alert.addButton(withTitle: "退出")

    let result = alert.runModal()
    if result == .alertSecondButtonReturn {
      NSApplication.shared.hide(nil)
    } else if result == .alertThirdButtonReturn {
      isQuitting = true
      NSApplication.shared.terminate(nil)
    }
  }
}
