#if APP_STORE
import AppKit
import StoreKit

@MainActor
final class PurchaseView: NSStackView {
    private let summary = NSTextField(labelWithString: "验证中")
    private let status = NSTextField(labelWithString: "正在验证 App Store 授权…")
    private let buy = NSButton(title: "永久解锁", target: nil, action: nil)
    private let restore = NSButton(title: "恢复购买", target: nil, action: nil)
    private let progress = NSProgressIndicator()
    private var product: Product?
    private var operation: Task<Void, Never>?
    private var updates: Task<Void, Never>?
    private var entitlement: PurchasePolicy.State = .unavailable
    private var isBusy = false

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 8
        let title = NSTextField(labelWithString: "购买与试用")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        summary.font = .systemFont(ofSize: 12, weight: .medium)
        summary.textColor = .secondaryLabelColor
        let header = NSStackView(views: [title, NSView(), summary])
        header.spacing = 12
        addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        status.font = .systemFont(ofSize: 12)
        status.maximumNumberOfLines = 2
        status.lineBreakMode = .byWordWrapping
        status.textColor = .secondaryLabelColor
        status.heightAnchor.constraint(equalToConstant: 34).isActive = true
        buy.bezelStyle = .rounded
        buy.isEnabled = false
        buy.target = self
        buy.action = #selector(purchase)
        buy.image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: nil)
        buy.imagePosition = .imageLeading
        restore.bezelStyle = .rounded
        restore.target = self
        restore.action = #selector(restorePurchase)
        restore.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        restore.imagePosition = .imageLeading
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        let actions = NSStackView(views: [buy, restore, progress])
        actions.spacing = 10
        addArrangedSubview(actions)
        heightAnchor.constraint(equalToConstant: 104).isActive = true
        #if !STOREKIT_UI_TEST
        operation = Task { [weak self] in
            await self?.load()
        }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard !Task.isCancelled else { break }
                guard case let .verified(transaction) = update,
                      transaction.productID == PurchasePolicy.productID,
                      StorePurchaseAccess.accepts(transaction.environment) else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
        #endif
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        operation?.cancel()
        updates?.cancel()
    }

    private func busy(_ value: Bool) {
        isBusy = value
        buy.isEnabled = !value && product != nil && entitlement != .unlocked
        restore.isEnabled = !value
        if value { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
    }

    private func refresh() async {
        update(await StorePurchaseAccess.state())
    }

    private func update(_ newState: PurchasePolicy.State) {
        entitlement = newState
        switch entitlement {
        case .unlocked:
            summary.stringValue = "已永久解锁"
            summary.textColor = .systemGreen
            status.stringValue = "一次性购买 · 永久使用"
        case let .trial(until):
            summary.stringValue = "完整试用中"
            summary.textColor = .controlAccentColor
            status.stringValue = "试用截至 \(until.formatted(date: .abbreviated, time: .shortened))\n永久解锁为一次性购买，翻译服务费用另计"
        case .expired:
            summary.stringValue = "试用已结束"
            summary.textColor = .systemOrange
            status.stringValue = "7 天完整试用已结束，永久解锁后可继续翻译"
        case .unavailable:
            summary.stringValue = "授权待验证"
            summary.textColor = .systemOrange
            status.stringValue = "无法验证 App Store 授权，请连接网络后恢复购买"
        }
        busy(isBusy)
    }

    private func load() async {
        busy(true)
        await refresh()
        busy(true)
        do {
            let products = try await StoreRequest.run {
                try await Product.products(for: [PurchasePolicy.productID])
            }
            guard let item = products.first, item.type == .nonConsumable else {
                throw NSError(domain: "MailTranslator.Store", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "解锁商品暂不可用，请稍后恢复购买重试"])
            }
            product = item
            buy.title = "永久解锁 \(item.displayPrice)"
        } catch { status.stringValue = error.localizedDescription }
        busy(false)
    }

    @objc private func purchase() {
        guard let product, buy.isEnabled else { return }
        busy(true)
        status.stringValue = "等待 App Store 确认购买…"
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                switch try await product.purchase() {
                case let .success(result):
                    guard case let .verified(transaction) = result,
                          transaction.productID == PurchasePolicy.productID,
                          transaction.productType == .nonConsumable,
                          StorePurchaseAccess.accepts(transaction.environment) else {
                        throw NSError(domain: "MailTranslator.Store", code: 3,
                                      userInfo: [NSLocalizedDescriptionKey: "购买凭证验证失败，未解锁"])
                    }
                    await transaction.finish()
                    await refresh()
                case .userCancelled: await refresh()
                case .pending: status.stringValue = "购买待批准，批准后会自动更新授权"
                @unknown default: status.stringValue = "购买未完成，请重试"
                }
            } catch { status.stringValue = error.localizedDescription }
            busy(false)
        }
    }

    @objc private func restorePurchase() {
        guard restore.isEnabled else { return }
        busy(true)
        status.stringValue = "正在验证已有购买，必要时请在 Apple 窗口完成登录…"
        operation = Task { [weak self] in
            guard let self else { return }
            defer { busy(false) }
            do {
                update(try await StorePurchaseAccess.restore())
                if entitlement == .unlocked {
                    status.stringValue = "已恢复永久购买 · 无需再次付费"
                } else if product == nil {
                    await load()
                }
            } catch is CancellationError {
                status.stringValue = "已取消恢复购买，现有授权不变"
            } catch StoreKitError.userCancelled {
                status.stringValue = "已取消恢复购买，现有授权不变"
            } catch {
                status.stringValue = "恢复购买未完成：\(error.localizedDescription)"
            }
        }
    }
}
#endif
