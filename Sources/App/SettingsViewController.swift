import AppKit

@MainActor
final class SettingsViewController: NSViewController {
    static let initialSize = NSSize(width: 720, height: 580)
    private let targets = TargetLanguage.allCases
    private let targetPopup = NSPopUpButton()
    private let statusLabel = NSTextField(wrappingLabelWithString: "设置保存后会立即在 Mail 中生效")
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)
    private let testButton = NSButton(title: "测试翻译", target: nil, action: nil)
    private let progress = NSProgressIndicator()
    private var config = TranslatorConfig.default
    private var testTask: Task<Void, Never>?

    deinit { testTask?.cancel() }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Self.initialSize))
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
        ])

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let title = NSTextField(labelWithString: "MailTranslator")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let header = NSStackView(views: [icon, title])
        header.spacing = 14
        root.addArrangedSubview(header)

        targets.forEach { targetPopup.addItem(withTitle: $0.displayName) }
        targetPopup.setAccessibilityLabel("目标语言")
        targetPopup.target = self
        targetPopup.action = #selector(languageChanged)
        let engine = NSTextField(labelWithString: "Apple 系统翻译")
        engine.setAccessibilityLabel("翻译引擎")
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "目标语言"), targetPopup],
            [NSTextField(labelWithString: "翻译引擎"), engine],
        ])
        grid.rowSpacing = 14
        grid.columnSpacing = 20
        grid.column(at: 0).width = 82
        grid.column(at: 1).xPlacement = .fill
        root.addArrangedSubview(grid)
        grid.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let resourceStatus = NSTextField(wrappingLabelWithString: "macOS 26+ · Apple 翻译语言资源")
        resourceStatus.textColor = .secondaryLabelColor
        resourceStatus.font = .systemFont(ofSize: 12)
        root.addArrangedSubview(resourceStatus)
        let separator = NSBox()
        separator.boxType = .separator
        root.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let purchase = PurchaseView()
        root.addArrangedSubview(purchase)
        purchase.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        root.addArrangedSubview(spacer)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 3
        root.addArrangedSubview(statusLabel)
        statusLabel.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        saveButton.bezelStyle = .rounded
        saveButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        saveButton.imagePosition = .imageLeading
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        saveButton.keyEquivalent = "\r"
        saveButton.isEnabled = false
        testButton.bezelStyle = .rounded
        testButton.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: nil)
        testButton.imagePosition = .imageLeading
        testButton.target = self
        testButton.action = #selector(testTranslation)
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        let footer = NSStackView(views: [NSView(), progress, testButton, saveButton])
        footer.spacing = 10
        root.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        do {
            let url = try SharedConfiguration.url()
            config = ConfigFile.load(TranslatorConfig.self, from: url) ?? .default
            // Re-encode the supported language only; never preserve legacy API credentials.
            if FileManager.default.fileExists(atPath: url.path) { try ConfigFile.save(config, to: url) }
        } catch { statusLabel.stringValue = error.localizedDescription }
        if let index = targets.firstIndex(of: config.target) { targetPopup.selectItem(at: index) }
    }

    @objc private func languageChanged() {
        guard targets.indices.contains(targetPopup.indexOfSelectedItem) else { return }
        config.targetLanguage = targets[targetPopup.indexOfSelectedItem].rawValue
        saveButton.isEnabled = true
    }

    @objc private func saveConfig() {
        do {
            try ConfigFile.save(config, to: SharedConfiguration.url())
            saveButton.isEnabled = false
            statusLabel.stringValue = "已保存"
            statusLabel.textColor = .systemGreen
        } catch {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        }
    }

    @objc private func testTranslation() {
        testTask?.cancel()
        testButton.isEnabled = false
        progress.startAnimation(nil)
        statusLabel.stringValue = "正在测试 Apple 翻译…"
        statusLabel.textColor = .secondaryLabelColor
        let target = config.target
        testTask = Task { [weak self] in
            guard let self else { return }
            defer { testButton.isEnabled = true; progress.stopAnimation(nil) }
            guard await StorePurchaseAccess.state().canTranslate else {
                statusLabel.stringValue = "请先开始免费试用或永久解锁"
                return
            }
            do {
                let input = TranslationInput(index: 0, html: "Hello", plainText: "Hello")
                let result = try await AppleTranslationEngine().translate(batch: [input], target: target) { _, _ in }
                try Task.checkCancellation()
                statusLabel.stringValue = result.isEmpty ? "未返回译文" : "测试成功"
                statusLabel.textColor = result.isEmpty ? .systemOrange : .systemGreen
            } catch is CancellationError {
                statusLabel.stringValue = "已取消"
            } catch {
                statusLabel.stringValue = error.localizedDescription
                statusLabel.textColor = .systemRed
            }
        }
    }
}
