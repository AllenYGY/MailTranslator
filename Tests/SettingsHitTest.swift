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
        #if APP_STORE
        window.setContentSize(NSSize(width: 660, height: 680))
        #else
        window.setContentSize(NSSize(width: 660, height: 550))
        #endif
        let root = controller.view
        root.layoutSubtreeIfNeeded()

        guard let providerContainer = descendants(of: root).first(where: {
            $0.identifier?.rawValue == "service-configuration"
        }), let providerControl = descendants(of: root).compactMap({ $0 as? NSSegmentedControl }).first else {
            fputs("FAIL: 找不到服务配置容器\n", stderr)
            exit(1)
        }
        var failures: [String] = []
        for index in ProviderKind.allCases.indices {
            providerControl.selectedSegment = index
            providerControl.performClick(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            root.layoutSubtreeIfNeeded()
            if !providerContainer.subviews.enumerated().allSatisfy({ $0.element.isHidden == ($0.offset != index) }) {
                failures.append("引擎 \(index) 切换失败")
            }
            failures += descendants(of: root)
            .compactMap { $0 as? NSControl }
            .filter { !isEffectivelyHidden($0) }
            .compactMap { control -> String? in
                let center = NSPoint(x: control.bounds.midX, y: control.bounds.midY)
                let point = root.convert(center, from: control)
                let rect = root.convert(control.bounds, from: control)
                if !root.bounds.insetBy(dx: -1, dy: -1).contains(rect) || rect.width <= 0 || rect.height <= 0 {
                    return "引擎 \(index)：\(type(of: control)) 超出窗口"
                }
                guard root.hitTest(point) !== control else { return nil }
                return "引擎 \(index)：\(type(of: control)) 点击被遮挡"
            }
        }

        guard failures.isEmpty else {
            fputs(
                "FAIL: \(failures.count) 个可见设置控件无法接收中心点击：\(failures.joined(separator: ", "))\n",
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
