import AppKit
import Darwin

@main
struct SettingsHitTest {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let controller = SettingsViewController()
        let window = NSWindow(contentViewController: controller)
        window.setContentSize(NSSize(width: 660, height: 500))
        let root = controller.view
        root.layoutSubtreeIfNeeded()

        guard let providerContainer = descendants(of: root).first(where: {
            $0.subviews.count == ProviderKind.allCases.count
                && $0.subviews.allSatisfy { type(of: $0) == NSView.self }
        }) else {
            fputs("FAIL: 找不到服务配置容器\n", stderr)
            exit(1)
        }
        for (index, providerView) in providerContainer.subviews.enumerated() {
            providerView.isHidden = index != 0
        }
        providerContainer.constraints.first(where: {
            $0.firstItem === providerContainer && $0.firstAttribute == .height
        })?.constant = 180
        root.layoutSubtreeIfNeeded()

        let failures = descendants(of: root)
            .compactMap { $0 as? NSControl }
            .filter { !isEffectivelyHidden($0) }
            .compactMap { control -> String? in
                let center = NSPoint(x: control.bounds.midX, y: control.bounds.midY)
                let point = root.convert(center, from: control)
                guard root.hitTest(point) !== control else { return nil }
                return String(describing: type(of: control))
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
