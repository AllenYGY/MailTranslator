import AppKit
import MailKit

/// 横幅"详情"弹层：显示当前引擎、目标语言与翻译状态。
final class PopoverViewController: MEExtensionViewController {
    private let key: String

    init(key: String) {
        self.key = key
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 140))
        preferredContentSize = NSSize(width: 360, height: 140)

        let config = Settings.current
        var lines = [
            "翻译引擎：\(config.providerKind.displayName)",
            "目标语言：\(config.target.displayName)",
        ]
        switch TranslationStore.shared.state(for: key) {
        case .idle:
            lines.append("状态：待翻译")
        case .translating(let completed, let total, _, _, _):
            lines.append("状态：正在翻译 \(completed)/\(total)")
        case .stopped(let completed, let total, _, _):
            lines.append("状态：已停止 \(completed)/\(total)")
        case .done:
            lines.append("状态：已完成")
        case .failed(let message, _, _):
            lines.append("状态：失败 - \(message)")
        }

        let label = NSTextField(wrappingLabelWithString: lines.joined(separator: "\n"))
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
        ])

        view = root
    }
}
