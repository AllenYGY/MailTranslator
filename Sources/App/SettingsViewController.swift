import AppKit

private enum SettingsValidationError: LocalizedError {
    case incomplete(String)

    var errorDescription: String? {
        switch self {
        case let .incomplete(message): return message
        }
    }
}

@MainActor
final class SettingsViewController: NSViewController, NSComboBoxDelegate {
    static var initialSize: NSSize {
        #if APP_STORE
        return NSSize(width: 720, height: 680)
        #else
        return NSSize(width: 720, height: 550)
        #endif
    }
    private let targetPopup = NSPopUpButton()
    private let providerControl = NSSegmentedControl()

    private let presetPopup = NSPopUpButton()
    private let openAIBaseField = NSTextField()
    private let openAIKeyField = NSSecureTextField()
    private let openAIModelCombo = NSComboBox()
    private let fetchModelsButton = NSButton()
    private let modelProgress = NSProgressIndicator()
    private let modelStatusLabel = NSTextField(labelWithString: "可手动输入模型名称")

    private let volcAKField = NSTextField()
    private let volcSKField = NSSecureTextField()

    private let providerContainer = NSView()
    private let openAIView = NSView()
    private let volcengineView = NSView()
    private let appleView = NSView()

    private let statusImage = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "配置保存后会立即在 Mail 中生效")
    private let testButton = NSButton()
    private let saveButton = NSButton()

    private let targets = TargetLanguage.allCases
    private let providers = ProviderKind.allCases
    private let presets = LLMProviderPreset.allCases

    private var loadedConfig = TranslatorConfig.default
    private var modelFetchTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var modelRequestGate = LatestRequestGate()
    private var isLoadingInitialConfig = true
    private var providerHeightConstraint: NSLayoutConstraint!

    private var configURL: URL {
        get throws {
        #if APP_STORE
        return try SharedConfiguration.url()
        #else
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Containers/\(BundleID.extension_)/Data/Library/Application Support/MailTranslator/config.json"
        )
        #endif
        }
    }

    deinit {
        modelFetchTask?.cancel()
        connectionTask?.cancel()
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Self.initialSize))
        view.wantsLayer = true
        configureControls()
        buildLayout()
        loadInitialConfig()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        resizeWindowForProvider(animated: false)
    }

    private func configureControls() {
        targets.forEach { targetPopup.addItem(withTitle: $0.displayName) }
        targetPopup.isEnabled = true
        targetPopup.target = self
        targetPopup.action = #selector(formValueChanged)

        providerControl.segmentCount = providers.count
        for (index, provider) in providers.enumerated() {
            providerControl.setLabel(providerSegmentTitle(provider), forSegment: index)
            providerControl.setToolTip(provider.displayName, forSegment: index)
            providerControl.setWidth(0, forSegment: index)
        }
        providerControl.trackingMode = .selectOne
        providerControl.segmentStyle = .rounded
        providerControl.isEnabled = true
        providerControl.target = self
        providerControl.action = #selector(providerSelectionCommitted(_:))

        presets.forEach { presetPopup.addItem(withTitle: $0.displayName) }
        presetPopup.autoenablesItems = false
        presetPopup.isEnabled = true
        presetPopup.target = self
        presetPopup.action = #selector(presetSelectionCommitted(_:))

        openAIBaseField.placeholderString = "https://api.example.com/v1"
        openAIBaseField.identifier = NSUserInterfaceItemIdentifier("api-url")
        openAIBaseField.setAccessibilityLabel("API 地址")
        openAIBaseField.isEditable = true
        openAIBaseField.isSelectable = true
        openAIBaseField.isEnabled = true
        openAIBaseField.delegate = self
        openAIKeyField.placeholderString = "API Key，本地服务可留空"
        openAIKeyField.setAccessibilityLabel("API Key")
        openAIKeyField.isEditable = true
        openAIKeyField.isSelectable = true
        openAIKeyField.isEnabled = true
        openAIKeyField.delegate = self

        openAIModelCombo.placeholderString = "选择或输入模型名称"
        openAIModelCombo.isEditable = true
        openAIModelCombo.isEnabled = true
        openAIModelCombo.completes = true
        openAIModelCombo.numberOfVisibleItems = 12
        openAIModelCombo.delegate = self

        fetchModelsButton.title = "获取模型"
        fetchModelsButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "获取模型")
        fetchModelsButton.imagePosition = .imageLeading
        fetchModelsButton.bezelStyle = .rounded
        fetchModelsButton.target = self
        fetchModelsButton.action = #selector(fetchModelsClicked)
        fetchModelsButton.isEnabled = true

        modelProgress.style = .spinning
        modelProgress.controlSize = .small
        modelProgress.isDisplayedWhenStopped = false
        modelStatusLabel.font = .systemFont(ofSize: 11)
        modelStatusLabel.textColor = .secondaryLabelColor

        volcAKField.placeholderString = "Access Key ID"
        volcAKField.delegate = self
        volcSKField.placeholderString = "Secret Access Key"
        volcSKField.delegate = self
        for field in [openAIBaseField, openAIKeyField, volcAKField, volcSKField] {
            field.bezelStyle = .roundedBezel
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        }
        openAIModelCombo.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        targetPopup.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        presetPopup.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true

        statusImage.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        statusImage.contentTintColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        testButton.title = "测试连接"
        testButton.image = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "测试连接")
        testButton.imagePosition = .imageLeading
        testButton.target = self
        testButton.action = #selector(testConnection)

        saveButton.title = "保存"
        saveButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "保存")
        saveButton.imagePosition = .imageLeading
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.bezelColor = .controlAccentColor
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        saveButton.isEnabled = false
    }

    private func buildLayout() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
        ])

        let header = makeHeader()
        root.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        root.addArrangedSubview(sectionLabel("翻译设置"))
        let generalGrid = makeGrid([
            ("目标语言", targetPopup),
            ("翻译引擎", providerControl),
        ])
        root.addArrangedSubview(generalGrid)
        generalGrid.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        root.addArrangedSubview(sectionLabel("服务配置"))
        buildProviderViews()
        root.addArrangedSubview(providerContainer)
        providerContainer.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        providerContainer.identifier = NSUserInterfaceItemIdentifier("service-configuration")
        providerHeightConstraint = providerContainer.heightAnchor.constraint(equalToConstant: 196)
        providerHeightConstraint.isActive = true

        #if APP_STORE
        let purchaseSeparator = NSBox()
        purchaseSeparator.boxType = .separator
        root.addArrangedSubview(purchaseSeparator)
        purchaseSeparator.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let purchaseView = PurchaseView()
        root.addArrangedSubview(purchaseView)
        purchaseView.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        #endif

        let spacer = NSView()
        root.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        let separator = NSBox()
        separator.boxType = .separator
        root.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let footer = makeFooter()
        root.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    private func makeHeader() -> NSView {
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 46),
            icon.heightAnchor.constraint(equalToConstant: 46),
        ])

        let title = NSTextField(labelWithString: "MailTranslator")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Mail 邮件翻译")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let header = NSStackView(views: [icon, text])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        return header
    }

    private func buildProviderViews() {
        let modelRow = NSStackView(views: [openAIModelCombo, fetchModelsButton])
        modelRow.orientation = .horizontal
        modelRow.alignment = .centerY
        modelRow.spacing = 8
        openAIModelCombo.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        fetchModelsButton.setContentHuggingPriority(.required, for: .horizontal)

        let openAIGrid = makeGrid([
            ("服务", presetPopup),
            ("API 地址", openAIBaseField),
            ("API Key", openAIKeyField),
            ("模型", modelRow),
        ])
        let modelStatus = NSStackView(views: [modelProgress, modelStatusLabel])
        modelStatus.orientation = .horizontal
        modelStatus.alignment = .centerY
        modelStatus.spacing = 6

        let openAIStack = NSStackView(views: [openAIGrid, modelStatus])
        openAIStack.orientation = .vertical
        openAIStack.alignment = .leading
        openAIStack.spacing = 10
        pin(openAIStack, to: openAIView)
        openAIGrid.widthAnchor.constraint(equalTo: openAIStack.widthAnchor).isActive = true

        let volcGrid = makeGrid([
            ("Access Key", volcAKField),
            ("Secret Key", volcSKField),
        ])
        pin(volcGrid, to: volcengineView)

        let appleIcon = NSImageView()
        appleIcon.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil)
        appleIcon.contentTintColor = .systemGreen
        appleIcon.setContentHuggingPriority(.required, for: .horizontal)
        let appleText = NSTextField(wrappingLabelWithString: "Apple 翻译 · macOS 26 或更高版本\n本地处理 · 无需 API Key")
        appleText.textColor = .secondaryLabelColor
        let appleStack = NSStackView(views: [appleIcon, appleText])
        appleStack.orientation = .horizontal
        appleStack.alignment = .top
        appleStack.spacing = 10
        pin(appleStack, to: appleView)

        for providerView in [openAIView, volcengineView, appleView] {
            providerView.translatesAutoresizingMaskIntoConstraints = false
            providerContainer.addSubview(providerView)
            NSLayoutConstraint.activate([
                providerView.leadingAnchor.constraint(equalTo: providerContainer.leadingAnchor),
                providerView.trailingAnchor.constraint(equalTo: providerContainer.trailingAnchor),
                providerView.topAnchor.constraint(equalTo: providerContainer.topAnchor),
                providerView.bottomAnchor.constraint(equalTo: providerContainer.bottomAnchor),
            ])
        }
    }

    private func makeFooter() -> NSView {
        let status = NSStackView(views: [statusImage, statusLabel])
        status.orientation = .horizontal
        status.alignment = .centerY
        status.spacing = 6
        statusImage.widthAnchor.constraint(equalToConstant: 16).isActive = true
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let buttons = NSStackView(views: [testButton, saveButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8
        buttons.setContentHuggingPriority(.required, for: .horizontal)

        let footer = NSStackView(views: [status, NSView(), buttons])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12
        return footer
    }

    private func makeGrid(_ rows: [(String, NSView)]) -> NSGridView {
        let views = rows.map { label, control -> [NSView] in
            let labelView = NSTextField(labelWithString: label)
            labelView.alignment = .right
            labelView.textColor = .secondaryLabelColor
            return [labelView, control]
        }
        let grid = NSGridView(views: views)
        grid.columnSpacing = 12
        grid.rowSpacing = 12
        grid.column(at: 0).width = 82
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        for index in rows.indices {
            grid.row(at: index).yPlacement = .center
        }
        return grid
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func pin(_ child: NSView, to parent: NSView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            child.topAnchor.constraint(equalTo: parent.topAnchor),
        ])
    }

    private func providerSegmentTitle(_ provider: ProviderKind) -> String {
        switch provider {
        case .openAICompatible: return "LLM"
        case .volcengine: return "火山翻译"
        case .apple: return "Apple 系统翻译"
        }
    }

    private var currentProvider: ProviderKind {
        let index = max(0, providerControl.selectedSegment)
        return providers[index]
    }

    private var currentLLMPreset: LLMProviderPreset {
        let index = max(0, presetPopup.indexOfSelectedItem)
        return presets[index]
    }

    private func loadInitialConfig() {
        do {
            loadedConfig = ConfigFile.load(TranslatorConfig.self, from: try configURL) ?? .default
        } catch {
            setStatus(error.localizedDescription, tone: .error)
        }
        loadLLMProfile(loadedConfig.activeLLMPreset)
        volcAKField.stringValue = loadedConfig.volcengine.accessKeyID
        volcSKField.stringValue = loadedConfig.volcengine.secretAccessKey

        if let index = targets.firstIndex(of: loadedConfig.target) {
            targetPopup.selectItem(at: index)
        }
        if let index = providers.firstIndex(of: loadedConfig.providerKind) {
            providerControl.selectedSegment = index
        } else {
            providerControl.selectedSegment = 0
        }
        selectPreset(loadedConfig.activeLLMPreset)
        updateProviderView()
        isLoadingInitialConfig = false
        saveButton.isEnabled = false
    }

    private func currentConfig(requireComplete: Bool) throws -> TranslatorConfig {
        var config = loadedConfig
        config.targetLanguage = targets[targetPopup.indexOfSelectedItem].rawValue
        config.activeProvider = currentProvider.rawValue
        var llmProfile = config.llmProfile(for: currentLLMPreset)
        llmProfile.baseURL = openAIBaseField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        llmProfile.model = openAIModelCombo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        llmProfile.apiKey = openAIKeyField.stringValue
        config.setActiveLLMProfile(llmProfile, for: currentLLMPreset)
        config.activeLLMPreset = currentLLMPreset
        config.volcengine.accessKeyID = volcAKField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.volcengine.secretAccessKey = volcSKField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !llmProfile.baseURL.isEmpty {
            _ = try APIEndpoint.url(from: llmProfile.baseURL)
        }
        if requireComplete && !config.isActiveProviderConfigured() {
            switch config.providerKind {
            case .openAICompatible:
                throw SettingsValidationError.incomplete("请填写 API 地址并选择或输入模型")
            case .volcengine:
                throw SettingsValidationError.incomplete("请填写火山翻译 Access Key 和 Secret Key")
            case .apple:
                break
            }
        }
        return config
    }

    @objc private func providerSelectionCommitted(_ sender: NSSegmentedControl) {
        DispatchQueue.main.async { [weak self] in
            guard let self, sender.selectedSegment >= 0 else { return }
            self.cancelModelFetch()
            self.updateProviderView()
            self.resizeWindowForProvider(animated: true)
            self.markDirty()
        }
    }

    private func updateProviderView() {
        openAIView.isHidden = currentProvider != .openAICompatible
        volcengineView.isHidden = currentProvider != .volcengine
        appleView.isHidden = currentProvider != .apple
        providerHeightConstraint?.constant = providerPanelHeight
    }

    private var providerPanelHeight: CGFloat {
        switch currentProvider {
        case .openAICompatible: return 196
        case .volcengine: return 85
        case .apple: return 60
        }
    }

    private var preferredWindowHeight: CGFloat {
        #if APP_STORE
        let purchaseHeight: CGFloat = 130
        #else
        let purchaseHeight: CGFloat = 0
        #endif
        switch currentProvider {
        case .openAICompatible: return 550 + purchaseHeight
        case .volcengine: return 440 + purchaseHeight
        case .apple: return 425 + purchaseHeight
        }
    }

    private func resizeWindowForProvider(animated: Bool) {
        guard let window = view.window else { return }
        window.contentMinSize = NSSize(width: 660, height: preferredWindowHeight)
        let currentFrame = window.frame
        var contentRect = window.contentRect(forFrameRect: currentFrame)
        contentRect.size.height = preferredWindowHeight
        var targetFrame = window.frameRect(forContentRect: contentRect)
        targetFrame.origin.x = currentFrame.origin.x
        targetFrame.origin.y = currentFrame.maxY - targetFrame.height
        window.setFrame(targetFrame, display: true, animate: animated)
    }

    @objc private func presetSelectionCommitted(_ sender: NSPopUpButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  sender.indexOfSelectedItem >= 0,
                  sender.indexOfSelectedItem < self.presets.count else {
                return
            }
            let preset = self.presets[sender.indexOfSelectedItem]
            self.cancelModelFetch()
            self.captureCurrentLLMProfile(for: self.loadedConfig.activeLLMPreset)
            self.loadedConfig.activeLLMPreset = preset
            self.loadLLMProfile(preset)
            self.markDirty()
        }
    }

    private func selectPreset(_ preset: LLMProviderPreset) {
        guard let index = presets.firstIndex(of: preset) else { return }
        presetPopup.selectItem(at: index)
    }

    private func loadLLMProfile(_ preset: LLMProviderPreset) {
        selectPreset(preset)
        let profile = loadedConfig.llmProfile(for: preset)
        openAIBaseField.stringValue = profile.baseURL
        openAIModelCombo.removeAllItems()
        openAIModelCombo.addItems(withObjectValues: profile.modelCatalog)
        openAIModelCombo.stringValue = profile.model
        openAIKeyField.stringValue = profile.apiKey

        let status: String
        if preset == .custom {
            status = "请输入兼容服务的 API 地址"
        } else if preset.hasDocumentedModelCatalog {
            status = "已填入推荐 API 地址，可获取模型"
        } else {
            status = "该服务可能需要手动输入模型 ID"
        }
        modelStatusLabel.stringValue = status
        modelStatusLabel.textColor = .secondaryLabelColor
    }

    private func captureCurrentLLMProfile(for preset: LLMProviderPreset) {
        var profile = loadedConfig.llmProfile(for: preset)
        profile.baseURL = openAIBaseField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.model = openAIModelCombo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.apiKey = openAIKeyField.stringValue
        loadedConfig.setActiveLLMProfile(profile, for: preset)
        loadedConfig.activeLLMPreset = preset
    }

    @objc private func formValueChanged() {
        markDirty()
    }

    private func markDirty() {
        guard !isLoadingInitialConfig else { return }
        saveButton.isEnabled = true
        setStatus("有尚未保存的更改", tone: .neutral)
    }

    func controlTextDidChange(_ notification: Notification) {
        if let control = notification.object as? NSControl,
           control === openAIBaseField || control === openAIKeyField {
            cancelModelFetch()
            clearCurrentModelCatalog()
            clearFetchedModels(status: "API 地址或密钥已更改，请重新获取模型")
        }
        markDirty()
    }

    @objc private func saveConfig() {
        do {
            let config = try currentConfig(requireComplete: true)
            try ConfigFile.save(config, to: configURL)
            loadedConfig = config
            saveButton.isEnabled = false
            setStatus("已保存，Mail 中立即生效", tone: .success)
        } catch {
            setStatus("保存失败：\(error.localizedDescription)", tone: .error)
        }
    }

    @objc private func fetchModelsClicked() {
        fetchModels()
    }

    private func fetchModels() {
        let baseURL = openAIBaseField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = openAIKeyField.stringValue
        modelFetchTask?.cancel()
        let requestToken = modelRequestGate.begin()
        setModelLoading(true, message: "正在获取模型列表…")

        modelFetchTask = Task { [weak self] in
            do {
                let models = try await OpenAIModelCatalog().fetch(baseURL: baseURL, apiKey: apiKey)
                try Task.checkCancellation()
                await MainActor.run {
                    guard let self, self.modelRequestGate.isCurrent(requestToken) else { return }
                    let current = self.openAIModelCombo.stringValue
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    self.openAIModelCombo.removeAllItems()
                    self.openAIModelCombo.addItems(withObjectValues: models)
                    if !current.isEmpty {
                        self.openAIModelCombo.stringValue = current
                    } else if let first = models.first {
                        self.openAIModelCombo.stringValue = first
                        self.markDirty()
                    }
                    var profile = self.loadedConfig.llmProfile(for: self.currentLLMPreset)
                    profile.baseURL = self.openAIBaseField.stringValue
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.apiKey = self.openAIKeyField.stringValue
                    profile.model = self.openAIModelCombo.stringValue
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.modelCatalog = models
                    self.loadedConfig.setActiveLLMProfile(profile, for: self.currentLLMPreset)
                    self.loadedConfig.activeLLMPreset = self.currentLLMPreset
                    self.setModelLoading(false, message: "已获取 \(models.count) 个模型", success: true)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.modelRequestGate.isCurrent(requestToken) else { return }
                    self.setModelLoading(false, message: error.localizedDescription, success: false)
                }
            }
        }
    }

    private func cancelModelFetch() {
        modelFetchTask?.cancel()
        modelFetchTask = nil
        modelRequestGate.invalidate()
        modelProgress.stopAnimation(nil)
        fetchModelsButton.isEnabled = true
    }

    private func clearFetchedModels(status: String) {
        let current = openAIModelCombo.stringValue
        openAIModelCombo.removeAllItems()
        openAIModelCombo.stringValue = current
        modelStatusLabel.stringValue = status
        modelStatusLabel.textColor = .secondaryLabelColor
    }

    private func clearCurrentModelCatalog() {
        var profile = loadedConfig.llmProfile(for: currentLLMPreset)
        profile.modelCatalog = []
        loadedConfig.setActiveLLMProfile(profile, for: currentLLMPreset)
    }

    private func setModelLoading(_ loading: Bool, message: String, success: Bool? = nil) {
        fetchModelsButton.isEnabled = !loading
        if loading {
            modelProgress.startAnimation(nil)
        } else {
            modelProgress.stopAnimation(nil)
        }
        modelStatusLabel.stringValue = message
        if success == true {
            modelStatusLabel.textColor = .systemGreen
        } else if success == false {
            modelStatusLabel.textColor = .systemRed
        } else {
            modelStatusLabel.textColor = .secondaryLabelColor
        }
    }

    @objc private func testConnection() {
        let config: TranslatorConfig
        let engine: TranslationEngine
        do {
            config = try currentConfig(requireComplete: true)
            engine = try EngineFactory.makeEngine(config: config)
        } catch {
            setStatus(error.localizedDescription, tone: .error)
            return
        }

        connectionTask?.cancel()
        testButton.isEnabled = false
        setStatus("正在测试 \(config.providerKind.displayName)…", tone: .progress)
        let input = TranslationInput(index: 0, html: "ping", plainText: "ping")
        connectionTask = Task { [weak self] in
            do {
                let results = try await engine.translate(batch: [input], target: config.target) { _, _ in }
                try Task.checkCancellation()
                let message = results.isEmpty ? "连接成功，但服务没有返回内容" : "连接成功"
                await MainActor.run {
                    self?.testButton.isEnabled = true
                    self?.setStatus(message, tone: .success)
                }
            } catch is CancellationError {
                await MainActor.run { self?.testButton.isEnabled = true }
            } catch {
                guard !Task.isCancelled else {
                    await MainActor.run { self?.testButton.isEnabled = true }
                    return
                }
                await MainActor.run {
                    self?.testButton.isEnabled = true
                    self?.setStatus("连接失败：\(error.localizedDescription)", tone: .error)
                }
            }
        }
    }

    private enum StatusTone {
        case neutral
        case progress
        case success
        case error
    }

    private func setStatus(_ message: String, tone: StatusTone) {
        statusLabel.stringValue = message
        let symbol: String
        let color: NSColor
        switch tone {
        case .neutral:
            symbol = "info.circle"
            color = .secondaryLabelColor
        case .progress:
            symbol = "ellipsis.circle"
            color = .controlAccentColor
        case .success:
            symbol = "checkmark.circle.fill"
            color = .systemGreen
        case .error:
            symbol = "exclamationmark.triangle.fill"
            color = .systemRed
        }
        statusImage.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        statusImage.contentTintColor = color
        statusLabel.textColor = color
    }
}
