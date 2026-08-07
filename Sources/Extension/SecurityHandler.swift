import CryptoKit
import Foundation
import MailKit
import os

/// 借用 MEMessageSecurityHandler 机制：拦截邮件解码，注入横幅按钮，改写正文显示译文。
final class SecurityHandler: NSObject, MEMessageSecurityHandler {
    static let shared = SecurityHandler()

    private static let logger = Logger(
        subsystem: "io.github.allenygy.mailtranslator",
        category: "SecurityHandler"
    )

    private let store = TranslationStore.shared
    private lazy var cache = TranslationCache(directory: Settings.cacheDirectory)
    private let taskRegistry = TranslationTaskRegistry()
    private static let refreshCoordinator = TranslationRefreshCoordinator(
        execute: { _, completion in
            DispatchQueue.main.async {
                SecurityHandler.logger.notice("reloadVisibleMessages START")
                MEExtensionManager.reloadVisibleMessages { error in
                    if let error {
                        SecurityHandler.logger.error("reloadVisibleMessages failed: \(error.localizedDescription, privacy: .public)")
                    } else {
                        SecurityHandler.logger.notice("reloadVisibleMessages SUCCEEDED")
                    }
                    completion()
                }
            }
        },
        schedule: { delay, callback in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: callback)
        }
    )

    func getEncodingStatus(
        for message: MEMessage,
        composeContext: MEComposeContext,
        completionHandler: @escaping (MEOutgoingMessageEncodingStatus) -> Void
    ) {
        completionHandler(
            MEOutgoingMessageEncodingStatus(
                canSign: false,
                canEncrypt: false,
                securityError: nil,
                addressesFailingEncryption: []
            )
        )
    }

    func encode(
        _ message: MEMessage,
        composeContext: MEComposeContext,
        completionHandler: @escaping (MEMessageEncodingResult) -> Void
    ) {
        completionHandler(
            MEMessageEncodingResult(
                encodedMessage: nil,
                signingError: nil,
                encryptionError: nil
            )
        )
    }

    func decodedMessage(forMessageData data: Data) -> MEDecodedMessage? {
        Self.logger.notice("decodedMessage called, data size=\(data.count)")
        let key = messageKey(for: data)
        let config = Settings.current

        switch store.state(for: key) {
        case .done(let rewritten, _):
            let showingOriginal = store.displayMode(for: key) == .original
            let original = store.stashed(key: key)?.original
            return decodedMessage(
                data: showingOriginal ? (original ?? rewritten) : rewritten,
                key: key,
                title: showingOriginal
                    ? "正在查看原文"
                    : "已翻译为\(config.target.displayName)（\(config.providerKind.displayName)）",
                primaryAction: showingOriginal && original != nil ? .showBilingual : .showOriginal
            )
        case .translating(let completed, let total, let latest, _, _):
            let message = decodedMessage(
                data: latest ?? data,
                key: key,
                title: total > 0 ? "正在翻译... \(completed)/\(total)" : "正在翻译...",
                primaryAction: .stop
            )
            store.markCancellationPresented(key: key)
            return message
        case .stopped(let completed, let total, let latest, _):
            return decodedMessage(
                data: latest ?? data,
                key: key,
                title: "翻译已停止 \(completed)/\(total)",
                primaryAction: .continueTranslation
            )
        case .failed(let message, let latest, _):
            return decodedMessage(
                data: latest ?? data,
                key: key,
                title: "翻译失败：\(message)",
                primaryAction: store.translations(key: key).isEmpty ? .retry : .continueTranslation
            )
        case .idle:
            break
        }

        let message = MIMEMessage(data: data)
        guard let part = message.displayPart(),
              let decoded = MIMEMessage.decodeBody(
                  data[part.bodyRange],
                  cte: part.cte,
                  charset: part.charset
              ) else {
            return nil
        }
        let sourceHTML = part.contentType == "text/html"
            ? decoded
            : HTMLSegments.htmlFromPlainText(decoded)
        let plainSource = part.contentType == "text/html"
            ? HTMLText.stripToPlainText(decoded)
            : decoded
        guard LanguageDetector.needsTranslation(plainSource, target: config.target) else {
            return nil
        }

        let segments = HTMLSegments.extract(from: sourceHTML)
        guard !segments.isEmpty else {
            return nil
        }

        let cacheKey = TranslationCache.cacheKey(
            messageKey: key,
            provider: config.providerKind.rawValue,
            target: config.target.rawValue
        )
        if let cached = cache.load(key: cacheKey), cached.count == segments.count {
            let stash = TranslationStore.Stash(
                contentType: part.contentType,
                original: data,
                sourceHTML: sourceHTML,
                segments: segments
            )
            store.stash(key: key, stash: stash)
            if let rewritten = Self.buildRewritten(stash: stash, translations: cached) {
                store.finish(key: key, rewritten: rewritten)
                return decodedMessage(
                    data: rewritten,
                    key: key,
                    title: "已翻译为\(config.target.displayName)（缓存）",
                    primaryAction: .showOriginal
                )
            }
        }

        store.stash(
            key: key,
            stash: TranslationStore.Stash(
                contentType: part.contentType,
                original: data,
                sourceHTML: sourceHTML,
                segments: segments
            )
        )
        let title = config.isActiveProviderConfigured()
            ? "这封邮件不是\(config.target.displayName)"
            : "邮件翻译：请打开 MailTranslator 应用配置翻译引擎"
        return decodedMessage(data: data, key: key, title: title, primaryAction: .start)
    }

    func extensionViewController(signers messageSigners: [MEMessageSigner]) -> MEExtensionViewController? {
        nil
    }

    func extensionViewController(messageContext context: Data) -> MEExtensionViewController? {
        nil
    }

    func primaryActionClicked(
        forMessageContext context: Data,
        completionHandler: @escaping (MEExtensionViewController?) -> Void
    ) {
        // macOS 26.5 exits Mail when this completion handler tears down the
        // extension host. Keep the request open and guard Mail's redelivery.
        Self.logger.notice("primaryActionClicked ENTER (open request, guarded reload)")
        guard let actionContext = TranslationActionContext(data: context) else {
            Self.logger.notice("primaryActionClicked ignored malformed context")
            return
        }
        guard let action = store.resolveAction(
            key: actionContext.key,
            token: actionContext.token,
            action: actionContext.action
        ) else {
            Self.logger.notice("primaryActionClicked ignored stale action context")
            return
        }
        let key = actionContext.key
        DispatchQueue.main.async { [self] in
            Self.logger.notice("primaryActionClicked processing key")
            switch action {
            case .showOriginal, .showBilingual:
                guard store.toggleOriginalView(key: key, action: action) else {
                    Self.logger.notice("primaryActionClicked ignored invalid display toggle")
                    return
                }
                Self.refreshCoordinator.request(.terminal)
                return
            case .stop:
                stopTranslation(key: key)
                return
            case .start, .retry, .retranslate, .continueTranslation:
                break
            }

            let lifecycleAction = Self.lifecycleAction(for: action)
            if lifecycleAction == .retranslate {
                store.reset(key: key)
            }

            guard let stash = store.stashed(key: key) else {
                store.fail(key: key, message: "请重新打开这封邮件")
                return
            }

            let config = Settings.current
            let engine: TranslationEngine
            do {
                engine = try EngineFactory.makeEngine(config: config)
            } catch {
                store.fail(key: key, message: error.localizedDescription)
                return
            }

            let preserveExisting = lifecycleAction == .continueTranslation
            let indexes = preserveExisting
                ? store.missingIndexes(key: key)
                : Array(stash.segments.indices)
            let inputs = indexes.map { index in
                let segment = stash.segments[index]
                return TranslationInput(
                    index: index,
                    html: segment.html,
                    plainText: HTMLText.stripToPlainText(segment.html)
                )
            }
            guard let generation = store.markTranslating(
                key: key,
                totalSegments: stash.segments.count,
                prefilled: [:],
                preserveExisting: preserveExisting
            ) else {
                return
            }

            let refreshCoordinator = Self.refreshCoordinator
            guard !inputs.isEmpty else {
                finishWithoutNetwork(
                    key: key,
                    generation: generation,
                    stash: stash,
                    config: config,
                    refreshCoordinator: refreshCoordinator
                )
                return
            }

            guard let handle = taskRegistry.reserve(key: key, generation: generation) else {
                if store.fail(key: key, generation: generation, message: "翻译任务仍在结束") {
                    refreshCoordinator.request(.terminal)
                }
                return
            }
            refreshCoordinator.request(.initial, afterReload: { [weak self] in
                guard let self else { return }
                let task = Task { [weak self] in
                    guard let self else { return }
                    await self.runTranslation(
                        key: key,
                        generation: generation,
                        stash: stash,
                        engine: engine,
                        config: config,
                        inputs: inputs,
                        refreshCoordinator: refreshCoordinator
                    )
                    self.taskRegistry.remove(handle)
                }
                _ = self.taskRegistry.attach(task, to: handle)
            })
        }
    }

    private func stopTranslation(key: String) {
        guard let generation = Self.generation(in: store.state(for: key)),
              store.stop(key: key, generation: generation) else {
            return
        }
        if let handle = taskRegistry.handle(for: key) {
            _ = taskRegistry.cancel(handle)
            taskRegistry.remove(handle)
        }
        Self.refreshCoordinator.request(.terminal)
    }

    private func runTranslation(
        key: String,
        generation: UInt,
        stash: TranslationStore.Stash,
        engine: TranslationEngine,
        config: TranslatorConfig,
        inputs: [TranslationInput],
        refreshCoordinator: TranslationRefreshCoordinator
    ) async {
        let pipeline = TranslationPipeline(engine: engine, target: config.target)
        do {
            let translations = try await pipeline.translate(
                inputs: inputs,
                onSegment: { _, _ in },
                onBatchResult: { [store] batch, _, _ in
                    let merged = store.translations(key: key).merging(batch) { _, new in new }
                    let rewritten = Self.buildRewritten(stash: stash, translations: merged)
                    guard store.updateProgress(
                        key: key,
                        generation: generation,
                        translations: batch,
                        rewritten: rewritten
                    ) else { return }
                    refreshCoordinator.request(.progress)
                }
            )

            guard store.missingIndexes(key: key).isEmpty else {
                if store.fail(key: key, generation: generation, message: "部分段落未完成") {
                    refreshCoordinator.request(.terminal)
                }
                return
            }
            let merged = store.translations(key: key).merging(translations) { _, new in new }
            guard let rewritten = Self.buildRewritten(stash: stash, translations: merged) else {
                if store.fail(key: key, generation: generation, message: "拼装译文失败") {
                    refreshCoordinator.request(.terminal)
                }
                return
            }
            guard store.finish(key: key, generation: generation, rewritten: rewritten) else { return }
            let cacheKey = TranslationCache.cacheKey(
                messageKey: key,
                provider: config.providerKind.rawValue,
                target: config.target.rawValue
            )
            cache.save(
                key: cacheKey,
                provider: config.providerKind.rawValue,
                target: config.target.rawValue,
                translations: merged
            )
            Self.logger.notice("translation finished")
            refreshCoordinator.request(.terminal)
        } catch is CancellationError {
            if store.stop(key: key, generation: generation) {
                refreshCoordinator.request(.terminal)
            }
            Self.logger.notice("translation stopped")
        } catch {
            if store.fail(key: key, generation: generation, message: error.localizedDescription) {
                refreshCoordinator.request(.terminal)
            }
            Self.logger.error("translation failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
        }
    }

    private func finishWithoutNetwork(
        key: String,
        generation: UInt,
        stash: TranslationStore.Stash,
        config: TranslatorConfig,
        refreshCoordinator: TranslationRefreshCoordinator
    ) {
        let translations = store.translations(key: key)
        guard let rewritten = Self.buildRewritten(stash: stash, translations: translations),
              store.finish(key: key, generation: generation, rewritten: rewritten) else {
            if store.fail(key: key, generation: generation, message: "拼装译文失败") {
                refreshCoordinator.request(.terminal)
            }
            return
        }
        let cacheKey = TranslationCache.cacheKey(
            messageKey: key,
            provider: config.providerKind.rawValue,
            target: config.target.rawValue
        )
        cache.save(
            key: cacheKey,
            provider: config.providerKind.rawValue,
            target: config.target.rawValue,
            translations: translations
        )
        refreshCoordinator.request(.terminal)
    }

    nonisolated static func buildRewritten(
        stash: TranslationStore.Stash,
        translations: [Int: String]
    ) -> Data? {
        guard !translations.isEmpty else { return nil }
        let ordered = stash.segments.indices.map { translations[$0] }
        let bilingual = HTMLSegments.insertingTranslations(
            ordered,
            into: stash.sourceHTML,
            segments: stash.segments
        )
        let message = MIMEMessage(data: stash.original)
        guard let part = message.displayPart() else { return nil }
        return MIMEMessage.replacing(
            part: part,
            with: Data(bilingual.utf8),
            contentType: "text/html",
            in: stash.original
        )
    }

    private func messageKey(for data: Data) -> String {
        if let messageID = MIMEMessage.headerValue("message-id", in: data), !messageID.isEmpty {
            return messageID
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func decodedMessage(
        data: Data,
        key: String,
        title: String,
        primaryAction: TranslationActionContext.Action
    ) -> MEDecodedMessage {
        let securityInformation = MEMessageSecurityInformation(
            signers: [],
            isEncrypted: false,
            signingError: nil,
            encryptionError: nil
        )
        let actionTitle = Self.actionTitle(for: primaryAction)
        let actionContext = store.present(key: key, action: primaryAction)
        let banner = MEDecodedMessageBanner(
            title: title,
            primaryActionTitle: actionTitle,
            dismissable: true
        )
        return MEDecodedMessage(
            data: data,
            securityInformation: securityInformation,
            context: actionContext.map { presentation in
                TranslationActionContext(
                    key: key,
                    token: presentation.token,
                    action: primaryAction
                ).dataRepresentation
            } ?? Data(),
            banner: banner
        )
    }

    private static func actionTitle(for action: TranslationActionContext.Action) -> String {
        switch action {
        case .start: return "翻译"
        case .stop: return "停止翻译"
        case .continueTranslation: return "继续翻译"
        case .retranslate: return "重新翻译"
        case .retry: return "重试"
        case .showOriginal: return "只看原文"
        case .showBilingual: return "查看双语译文"
        }
    }

    private static func lifecycleAction(for action: TranslationActionContext.Action) -> TranslationStore.Action {
        switch action {
        case .start: return .start
        case .stop: return .stop
        case .continueTranslation: return .continueTranslation
        case .retranslate: return .retranslate
        case .retry: return .retry
        case .showOriginal, .showBilingual: return .ignoreRedelivery
        }
    }

    private static func generation(in state: TranslationStore.State) -> UInt? {
        switch state {
        case .translating(_, _, _, _, let generation),
             .stopped(_, _, _, let generation),
             .done(_, let generation),
             .failed(_, _, let generation):
            return generation
        case .idle:
            return nil
        }
    }
}
