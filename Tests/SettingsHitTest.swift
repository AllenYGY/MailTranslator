import AppKit
import Darwin

@main
struct SettingsHitTest {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let controller = SettingsViewController()
        let window = NSWindow(contentViewController: controller)
        defer { window.orderOut(nil) }
        window.setContentSize(SettingsViewController.initialSize)
        let root = controller.view
        root.layoutSubtreeIfNeeded()

        var failures: [String] = []
        guard descendants(of: root).contains(where: { $0 is NSPopUpButton }) else {
            fputs("FAIL: 找不到目标语言选择控件\n", stderr)
            exit(1)
        }
        let controls = descendants(of: root)
            .compactMap { $0 as? NSControl }
            .filter { !isEffectivelyHidden($0) }
        if controls.isEmpty { failures.append("设置窗口没有任何可见控件") }
        for control in controls {
            let center = NSPoint(x: control.bounds.midX, y: control.bounds.midY)
            let point = root.convert(center, from: control)
            let rect = root.convert(control.bounds, from: control)
            if !root.bounds.insetBy(dx: -1, dy: -1).contains(rect) || rect.width <= 0 || rect.height <= 0 {
                failures.append("\(type(of: control)) 超出窗口")
                continue
            }
            if root.hitTest(point) !== control {
                failures.append("\(type(of: control)) 点击被遮挡")
            }
        }

        guard failures.isEmpty else {
            fputs(
                "FAIL: \(failures.count) 个可见设置控件有问题：\(failures.joined(separator: ", "))\n",
                stderr
            )
            exit(1)
        }
        print("Settings hit-test passed")
    }

    @MainActor
    private static func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }

    @MainActor
    private static func isEffectivelyHidden(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let item = current {
            if item.isHidden { return true }
            current = item.superview
        }
        return false
    }
}
