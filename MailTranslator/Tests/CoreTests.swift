import Foundation

private extension NSLock {
    func testWithLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

private actor CancellationTestState {
    private var startedBatches = 0
    private var firstStartWaiter: CheckedContinuation<Void, Never>?

    func recordStart() {
        startedBatches += 1
        firstStartWaiter?.resume()
        firstStartWaiter = nil
    }

    func waitForFirstStart() async {
        guard startedBatches == 0 else { return }
        await withCheckedContinuation { firstStartWaiter = $0 }
    }

    func count() -> Int { startedBatches }
}

private struct CancellableTestEngine: TranslationEngine {
    let state: CancellationTestState

    var kind: ProviderKind { .apple }
    var batchCharacterLimit: Int { 20 }
    var maxConcurrentBatches: Int { 1 }

    func translate(
        batch: [TranslationInput],
        target: TargetLanguage,
        onSegment: @Sendable (Int, String) -> Void
    ) async throws -> [Int: String] {
        await state.recordStart()
        try await Task.sleep(nanoseconds: 30_000_000_000)
        return Dictionary(uniqueKeysWithValues: batch.map { ($0.index, "translated") })
    }
}

private final class ManualRefreshClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 100)

    func now() -> Date { lock.testWithLock { value } }
    func advance(by interval: TimeInterval) { lock.testWithLock { value.addTimeInterval(interval) } }
}

private final class ManualRefreshExecutor: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var starts: [TranslationRefreshCoordinator.Request] = []
    private var completions: [() -> Void] = []

    func execute(_ request: TranslationRefreshCoordinator.Request, completion: @escaping () -> Void) {
        lock.testWithLock {
            starts.append(request)
            completions.append(completion)
        }
    }

    func completeNext() {
        let completion = lock.testWithLock { completions.removeFirst() }
        completion()
    }
}

private final class ManualRefreshSchedule: @unchecked Sendable {
    private let lock = NSLock()
    private var callbacks: [() -> Void] = []

    func schedule(after _: TimeInterval, _ callback: @escaping () -> Void) {
        lock.testWithLock { callbacks.append(callback) }
    }

    func fireNext() {
        let callback = lock.testWithLock { callbacks.removeFirst() }
        callback()
    }

    var count: Int { lock.testWithLock { callbacks.count } }
}

@main
struct CoreTests {
    static func main() async throws {
        var failureCount = 0

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() {
                failureCount += 1
                fputs("FAIL: \(message)\n", stderr)
            }
        }

        // MARK: APIEndpoint

        let remote = try APIEndpoint.url(from: "https://api.example.com/v1")
        expect(
            remote.absoluteString == "https://api.example.com/v1/chat/completions",
            "HTTPS 地址应补全 chat/completions"
        )
        let complete = try APIEndpoint.url(from: "https://api.example.com/v1/chat/completions/")
        expect(
            complete.absoluteString == "https://api.example.com/v1/chat/completions",
            "完整端点不应重复追加路径"
        )
        let modelsFromBase = try APIEndpoint.modelsURL(from: "https://api.example.com/v1")
        expect(
            modelsFromBase.absoluteString == "https://api.example.com/v1/models",
            "基础地址应补全 models"
        )
        let modelsFromChat = try APIEndpoint.modelsURL(
            from: "https://api.example.com/v1/chat/completions/"
        )
        expect(
            modelsFromChat.absoluteString == "https://api.example.com/v1/models",
            "聊天端点应替换为同级 models"
        )
        let chatFromModels = try APIEndpoint.url(from: "https://api.example.com/v1/models")
        expect(
            chatFromModels.absoluteString == "https://api.example.com/v1/chat/completions",
            "模型端点应替换为同级 chat/completions"
        )
        for address in [
            "http://localhost:8000/v1",
            "http://127.0.0.1:8000/v1",
            "http://[::1]:8000/v1",
            "http://10.0.0.1/v1",
            "http://172.16.0.1/v1",
            "http://192.168.1.1/v1",
        ] {
            let local = try APIEndpoint.url(from: address)
            expect(local.scheme == "http", "回环/私网地址应允许 HTTP：\(address)")
        }
        for address in ["http://api.example.com/v1", "http://127.0.0.1.evil.com/v1"] {
            do {
                _ = try APIEndpoint.url(from: address)
                expect(false, "远程 HTTP 地址应被拒绝：\(address)")
            } catch {}
        }

        // MARK: OpenAIModelCatalog

        let authorizedModelRequest = try OpenAIModelCatalog.makeRequest(
            baseURL: "https://api.example.com/v1/chat/completions",
            apiKey: "secret"
        )
        expect(authorizedModelRequest.httpMethod == "GET", "模型目录必须使用 GET")
        expect(
            authorizedModelRequest.url?.absoluteString == "https://api.example.com/v1/models",
            "模型目录请求应使用同级 models 端点"
        )
        expect(
            authorizedModelRequest.value(forHTTPHeaderField: "Authorization") == "Bearer secret",
            "非空 API Key 应作为 Bearer 凭证"
        )
        let localModelRequest = try OpenAIModelCatalog.makeRequest(
            baseURL: "http://localhost:11434/v1",
            apiKey: ""
        )
        expect(
            localModelRequest.value(forHTTPHeaderField: "Authorization") == nil,
            "空 API Key 不应发送 Authorization"
        )

        let modelPayload = Data(#"{"object":"list","data":[{"id":"zeta"},{"id":"alpha"},{"id":"alpha"},{"id":"  "}]}"#.utf8)
        let decodedModels = try OpenAIModelCatalog.decodeModels(from: modelPayload)
        expect(decodedModels == ["alpha", "zeta"], "模型列表应去空、去重并排序：\(decodedModels)")
        do {
            _ = try OpenAIModelCatalog.decodeModels(
                from: Data(#"{"object":"list","data":[]}"#.utf8)
            )
            expect(false, "空模型列表应返回可恢复错误")
        } catch {
            expect(
                error.localizedDescription.contains("没有返回可用模型"),
                "空模型列表错误应可直接显示：\(error.localizedDescription)"
            )
        }
        let deniedResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/v1/models")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        do {
            _ = try OpenAIModelCatalog.validate(
                data: Data(#"{"error":{"message":"invalid key"}}"#.utf8),
                response: deniedResponse
            )
            expect(false, "非 2xx 模型目录响应应失败")
        } catch {
            expect(
                error.localizedDescription.contains("401")
                    && error.localizedDescription.contains("invalid key"),
                "HTTP 错误应包含状态码和服务端消息：\(error.localizedDescription)"
            )
        }

        // MARK: LLMProviderPreset

        expect(
            LLMProviderPreset.deepSeek.baseURL == "https://api.deepseek.com",
            "DeepSeek 预设应使用官方兼容地址"
        )
        expect(
            LLMProviderPreset.ollama.baseURL == "http://localhost:11434/v1",
            "Ollama 预设应使用本地 OpenAI 兼容地址"
        )
        expect(
            !LLMProviderPreset.dashScope.hasDocumentedModelCatalog
                && !LLMProviderPreset.volcengineArk.hasDocumentedModelCatalog,
            "未正式提供 OpenAI 模型目录的服务应提示手动模型回退"
        )
        expect(
            LLMProviderPreset.matching(
                baseURL: "https://api.deepseek.com/chat/completions/"
            ) == .deepSeek,
            "完整聊天端点应识别为对应预设"
        )
        expect(
            LLMProviderPreset.matching(baseURL: "https://gateway.example.com/openai/v1") == .custom,
            "未知兼容服务应保留为自定义地址"
        )

        var requestGate = LatestRequestGate()
        let firstRequest = requestGate.begin()
        let secondRequest = requestGate.begin()
        expect(!requestGate.isCurrent(firstRequest), "后发请求应使旧请求失效")
        expect(requestGate.isCurrent(secondRequest), "最新请求应保持有效")
        requestGate.invalidate()
        expect(!requestGate.isCurrent(secondRequest), "主动取消应使当前请求失效")
        expect(
            !ApplicationStatePolicy.restoresSettingsControls,
            "设置控件不得被 AppKit 状态恢复覆盖配置文件"
        )

        // MARK: TranslatorConfig

        var config = TranslatorConfig.default
        expect(config.providerKind == .openAICompatible, "默认引擎应为 OpenAI 兼容")
        expect(config.target == .zhHans, "默认目标语言应为简体中文")
        expect(!config.isActiveProviderConfigured(), "默认未配置")
        config.activeProvider = "volcengine"
        config.volcengine.accessKeyID = "AK"
        config.volcengine.secretAccessKey = "SK"
        expect(config.providerKind == .volcengine && config.isActiveProviderConfigured(),
               "火山配置后应为已配置")
        let codec = try JSONDecoder().decode(
            TranslatorConfig.self,
            from: JSONEncoder().encode(config)
        )
        expect(codec == config, "TranslatorConfig 编解码应往返一致")

        // MARK: LLM provider profiles

        var profilesConfig = TranslatorConfig.default
        profilesConfig.setActiveLLMProfile(
            OpenAIProviderConfig(
                baseURL: "https://api.openai.com/v1",
                model: "gpt-4o-mini",
                apiKey: "openai-key",
                modelCatalog: ["gpt-4o-mini", "gpt-4.1-mini"]
            ),
            for: .openAI
        )
        profilesConfig.setActiveLLMProfile(
            OpenAIProviderConfig(
                baseURL: "https://api.deepseek.com",
                model: "deepseek-chat",
                apiKey: "deepseek-key",
                modelCatalog: ["deepseek-chat"]
            ),
            for: .deepSeek
        )
        profilesConfig.activeLLMPreset = .deepSeek
        expect(
            profilesConfig.activeLLMProfile.apiKey == "deepseek-key",
            "切换到 DeepSeek 后必须读取 DeepSeek 自己的 Key"
        )
        expect(
            profilesConfig.activeLLMProfile.modelCatalog == ["deepseek-chat"],
            "切换到 DeepSeek 后必须读取 DeepSeek 自己的模型列表"
        )
        profilesConfig.activeLLMPreset = .openAI
        expect(
            profilesConfig.activeLLMProfile.apiKey == "openai-key",
            "切回 OpenAI 后必须恢复 OpenAI 自己的 Key"
        )
        expect(
            profilesConfig.activeLLMProfile.modelCatalog == ["gpt-4o-mini", "gpt-4.1-mini"],
            "切回 OpenAI 后必须恢复 OpenAI 自己的模型列表"
        )

        let legacyJSON = Data(#"""
        {
            "targetLanguage": "zh-Hans",
            "activeProvider": "openai-compatible",
            "openAI": {
                "baseURL": "https://api.deepseek.com",
                "model": "deepseek-chat",
                "apiKey": "legacy-deepseek-key"
            },
            "volcengine": {
                "accessKeyID": "",
                "secretAccessKey": ""
            }
        }
        """#.utf8)
        let migrated = try JSONDecoder().decode(TranslatorConfig.self, from: legacyJSON)
        expect(migrated.activeLLMPreset == .deepSeek, "旧配置应按 API 地址迁移到 DeepSeek 配置")
        expect(
            migrated.activeLLMProfile.apiKey == "legacy-deepseek-key",
            "旧版 openAI Key 迁移后必须保留"
        )
        let encodedProfiles = try JSONEncoder().encode(migrated)
        let encodedText = String(decoding: encodedProfiles, as: UTF8.self)
        expect(!encodedText.contains("\"openAI\""), "新配置不应继续写入共享 openAI 字段")

        // MARK: MarkerStreamParser

        do {
            var parser = MarkerStreamParser()
            let emitted = parser.append("@@0@@\n你好世界\n@@1@@\n第二段\n")
            expect(emitted.count == 1 && emitted[0].0 == 0 && emitted[0].1 == "你好世界",
                   "一次性输入应在第二标记出现时才产出第一段：\(emitted)")
            let flushed = parser.finish()
            expect(flushed.count == 1 && flushed[0].0 == 1 && flushed[0].1 == "第二段",
                   "finish 应冲刷最后一段：\(flushed)")
        }
        do {
            var parser = MarkerStreamParser()
            var all: [(Int, String)] = []
            for piece in ["@@0", "@@\n你", "好\n", "@@1", "@@\nOK\n@@", "2@@\nDone\n"] {
                all += parser.append(piece)
            }
            all += parser.finish()
            expect(all.count == 3, "跨包拆分的标记应正确重组：\(all)")
            expect(
                all[0].0 == 0 && all[0].1 == "你好"
                    && all[1].0 == 1 && all[1].1 == "OK"
                    && all[2].0 == 2 && all[2].1 == "Done",
                "重组结果内容应正确：\(all)"
            )
        }
        do {
            var parser = MarkerStreamParser()
            expect(parser.append("没有任何标记的内容\n").isEmpty, "无标记时不应产出")
            expect(parser.finish().isEmpty, "无标记时 finish 也不应产出")
        }

        // MARK: planBatches

        let inputs = (0..<10).map {
            TranslationInput(index: $0, html: String(repeating: "x", count: 100), plainText: "t")
        }
        let batches = TranslationPipeline.planBatches(inputs, characterLimit: 300)
        expect(batches.count == 5, "10 段每批 300 字符应分 5 批：\(batches.count)")
        expect(batches.allSatisfy { !$0.isEmpty }, "不应有空批次")
        expect(batches.flatMap { $0 }.map(\.index) == Array(0..<10), "分批应保持顺序与不丢段")
        expect(TranslationPipeline.planBatches([], characterLimit: 100).isEmpty, "空输入应为空批次")

        // MARK: InsertionHTML

        let escaped = InsertionHTML.fromPlainText("a<b>&\"x\"\n换行")
        expect(escaped == "a&lt;b&gt;&amp;\"x\"<br>换行", "纯文本应转义并转换换行：\(escaped)")

        // MARK: VolcengineSigner

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let signed = VolcengineSigner.sign(
            accessKeyID: "AKIDEXAMPLE",
            secretAccessKey: "secret",
            host: "translate.volcengineapi.com",
            uri: "/",
            queryString: "Action=TranslateText&Version=2020-06-01",
            region: "cn-north-1",
            service: "translate",
            body: Data(),
            date: fixedDate
        )
        expect(signed.xDate == "20231114T221320Z", "X-Date 格式应为 yyyyMMddTHHmmssZ：\(signed.xDate)")
        expect(
            signed.authorization.hasPrefix(
                "HMAC-SHA256 Credential=AKIDEXAMPLE/20231114/cn-north-1/translate/request"
            ),
            "Authorization 应包含正确的凭证范围：\(signed.authorization)"
        )
        expect(signed.authorization.contains("SignedHeaders=content-type;host;x-date"),
               "SignedHeaders 应固定")
        expect(signed.authorization.contains("Signature="), "应包含签名")
        expect(
            VolcengineSigner.sha256Hex(Data())
                == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "空内容的 SHA256 应为已知常量"
        )
        let signedAgain = VolcengineSigner.sign(
            accessKeyID: "AKIDEXAMPLE",
            secretAccessKey: "secret",
            host: "translate.volcengineapi.com",
            uri: "/",
            queryString: "Action=TranslateText&Version=2020-06-01",
            region: "cn-north-1",
            service: "translate",
            body: Data(),
            date: fixedDate
        )
        expect(signed.authorization == signedAgain.authorization, "相同输入签名应确定一致")

        // MARK: 语言支持

        expect(TargetLanguage.zhHans.volcCode == "zh", "简中火山代码")
        expect(TargetLanguage.ja.volcCode == "ja", "日语火山代码")
        expect(
            !LanguageDetector.needsTranslation(
                "这是一封中文邮件，正文内容已经足够长了，写了很多很多字，所以肯定不需要再翻译成中文了。",
                target: .zhHans
            ),
            "中文邮件不应再翻译成中文"
        )
        expect(
            LanguageDetector.needsTranslation(
                "Hello, this is a fairly long English email message that certainly should be translated.",
                target: .zhHans
            ),
            "英文邮件应需要翻译"
        )

        // MARK: TranslationCache

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mt-cache-test-\(UUID().uuidString)")
        let translationCache = TranslationCache(directory: tempDir)
        translationCache.save(key: "k1", provider: "volcengine", target: "zh-Hans", translations: [0: "你好", 3: "世界"])
        let loaded = translationCache.load(key: "k1")
        expect(loaded?[0] == "你好" && loaded?[3] == "世界" && loaded?.count == 2,
               "缓存应往返一致：\(String(describing: loaded))")
        expect(translationCache.load(key: "missing") == nil, "缺失键应返回 nil")
        try? FileManager.default.removeItem(at: tempDir)

        let actionGate = TranslationActionGate(cooldown: 3)
        let actionStart = Date(timeIntervalSince1970: 100)
        expect(actionGate.begin(key: "message-a", now: actionStart), "首次点击应启动翻译")
        expect(
            !actionGate.begin(key: "message-a", now: actionStart.addingTimeInterval(1)),
            "冷却窗口内的重复回调不应再次启动"
        )
        expect(
            actionGate.begin(key: "message-a", now: actionStart.addingTimeInterval(4)),
            "冷却结束后的用户点击应允许重新翻译"
        )
        expect(
            actionGate.begin(key: "message-b", now: actionStart.addingTimeInterval(1)),
            "不同邮件不应共享冷却状态"
        )

        // MARK: TranslationStore action state

        let store = TranslationStore.shared
        let sourceHTML = "<p>First paragraph</p><p>Second paragraph</p><p>Third paragraph</p>"
        let stash = TranslationStore.Stash(
            contentType: "text/html",
            original: Data(sourceHTML.utf8),
            sourceHTML: sourceHTML,
            segments: HTMLSegments.extract(from: sourceHTML)
        )
        store.stash(key: "message", stash: stash)
        let generation = store.markTranslating(
            key: "message",
            totalSegments: 3,
            prefilled: [:]
        )
        expect(generation != nil, "空闲邮件应开始翻译")
        expect(store.action(for: "message") == .ignoreRedelivery, "横幅显示前的重复回调应被忽略")
        store.markCancellationPresented(key: "message")
        expect(store.action(for: "message") == .stop, "显示停止按钮后应允许取消")
        expect(store.updateProgress(
            key: "message",
            generation: generation!,
            translations: [0: "第一段"],
            rewritten: Data("partial".utf8)
        ), "当前任务应接受进度")
        expect(store.stop(key: "message", generation: generation!), "当前任务应停止")
        expect(store.translations(key: "message")[0] == "第一段", "停止时必须保留完成译文")
        expect(store.action(for: "message") == .continueTranslation, "停止后应允许继续翻译")
        expect(!store.fail(key: "message", generation: generation!, message: "late failure"), "停止后的旧任务不得覆盖停止状态")
        expect(store.action(for: "message") == .continueTranslation, "停止状态必须优先于迟到错误")
        expect(store.missingIndexes(key: "message") == [1, 2], "继续时只应提交缺失段落")

        let originalViewKey = "original-view-message"
        store.stash(key: originalViewKey, stash: stash)
        store.finish(key: originalViewKey, rewritten: Data("bilingual".utf8))
        let originalPresentation = store.present(key: originalViewKey, action: .showOriginal)
        let duplicateOriginalPresentation = store.present(key: originalViewKey, action: .showOriginal)
        expect(originalPresentation?.displayMode == .bilingual, "完成邮件默认显示双语正文")
        expect(
            originalPresentation?.token == duplicateOriginalPresentation?.token,
            "Mail 重复解码同一横幅时必须复用展示令牌"
        )
        expect(
            store.resolveAction(
                key: originalViewKey,
                token: duplicateOriginalPresentation!.token,
                action: .showOriginal
            ) == .showOriginal,
            "当前横幅令牌必须接受展示的操作"
        )
        _ = store.present(key: originalViewKey, action: .showOriginal)
        expect(
            store.toggleOriginalView(key: originalViewKey, action: .showOriginal),
            "已接受的原文点击不得因随后刷新而失效"
        )
        expect(store.displayMode(for: originalViewKey) == .original, "切换后应显示原文")
        expect(store.translations(key: originalViewKey).isEmpty, "切换显示不得创建或修改译文")
        let bilingualPresentation = store.present(key: originalViewKey, action: .showBilingual)
        expect(
            store.resolveAction(
                key: originalViewKey,
                token: bilingualPresentation!.token,
                action: .showBilingual
            ) == .showBilingual,
            "原文视图横幅必须允许返回双语正文"
        )
        expect(
            store.toggleOriginalView(key: originalViewKey, action: .showBilingual),
            "已完成邮件应可从原文返回双语正文"
        )
        expect(store.displayMode(for: originalViewKey) == .bilingual, "返回操作应恢复双语正文")
        expect(
            store.resolveAction(
                key: originalViewKey,
                token: originalPresentation!.token,
                action: .showOriginal
            ) == nil,
            "已消费的横幅令牌不得再次执行"
        )
        let actionContext = TranslationActionContext(
            key: originalViewKey,
            token: 42,
            action: .showBilingual
        )
        expect(
            TranslationActionContext(data: actionContext.dataRepresentation) == actionContext,
            "横幅操作上下文必须可往返编码"
        )
        expect(
            TranslationActionContext(data: Data("not-json".utf8)) == nil,
            "畸形横幅操作上下文必须被拒绝"
        )

        // MARK: TranslationPipeline cancellation

        let cancellationState = CancellationTestState()
        let cancellationInputs = [
            TranslationInput(index: 0, html: "first batch", plainText: "first batch"),
            TranslationInput(index: 1, html: "second batch", plainText: "second batch"),
        ]
        let cancellationTask = Task {
            try await TranslationPipeline(
                engine: CancellableTestEngine(state: cancellationState),
                target: .zhHans
            ).translate(
                inputs: cancellationInputs,
                onSegment: { _, _ in },
                onBatchResult: { _, _, _ in }
            )
        }
        await cancellationState.waitForFirstStart()
        cancellationTask.cancel()
        do {
            _ = try await cancellationTask.value
            expect(false, "取消后的翻译管线必须抛出 CancellationError")
        } catch is CancellationError {
            // Expected.
        } catch {
            expect(false, "取消不应被转换成普通错误：\(error)")
        }
        let startedBatchCount = await cancellationState.count()
        expect(startedBatchCount == 1, "取消后不得启动新的批次")

        // MARK: Task registry and refresh scheduling

        let registry = TranslationTaskRegistry()
        let reservedHandle = registry.reserve(key: "reserved", generation: 99)
        expect(reservedHandle != nil, "启动前预留任务必须立即可见")
        expect(registry.handle(for: "reserved") == reservedHandle, "预留任务的句柄必须稳定")
        expect(registry.cancelReservation(reservedHandle!), "未启动任务的预留必须可以取消")
        expect(
            !registry.attach(Task<Void, Never> {}, to: reservedHandle!),
            "取消后的预留不得接受迟到任务"
        )
        let firstTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
        let firstHandle = registry.register(key: "active", task: firstTask)
        expect(firstHandle != nil, "首个任务应注册成功")
        let duplicateTask = Task<Void, Never> {}
        expect(registry.register(key: "active", task: duplicateTask) == nil, "同一邮件不得注册两个任务")
        expect(registry.cancel(firstHandle!), "已注册任务应可取消")
        registry.remove(firstHandle!)
        let secondTask = Task<Void, Never> {}
        let secondHandle = registry.register(key: "active", task: secondTask)
        expect(secondHandle != nil, "移除旧任务后应允许续译任务注册")
        registry.remove(firstHandle!)
        expect(registry.handle(for: "active") == secondHandle, "旧任务不得移除新任务")
        registry.remove(secondHandle!)

        let refreshClock = ManualRefreshClock()
        let refreshExecutor = ManualRefreshExecutor()
        let refreshSchedule = ManualRefreshSchedule()
        let refreshCoordinator = TranslationRefreshCoordinator(
            minimumProgressInterval: 1,
            now: refreshClock.now,
            execute: refreshExecutor.execute,
            schedule: refreshSchedule.schedule
        )
        let startupClock = ManualRefreshClock()
        let startupExecutor = ManualRefreshExecutor()
        let startupSchedule = ManualRefreshSchedule()
        let startupCoordinator = TranslationRefreshCoordinator(
            minimumProgressInterval: 1,
            now: startupClock.now,
            execute: startupExecutor.execute,
            schedule: startupSchedule.schedule
        )
        var initialReloadFinished = false
        startupCoordinator.request(.initial, afterReload: {
            initialReloadFinished = true
        })
        expect(!initialReloadFinished, "翻译任务必须等待初始 Mail 刷新结束")
        startupExecutor.completeNext()
        expect(initialReloadFinished, "初始 Mail 刷新结束后才可启动翻译任务")

        let sharedClock = ManualRefreshClock()
        let sharedExecutor = ManualRefreshExecutor()
        let sharedSchedule = ManualRefreshSchedule()
        let sharedCoordinator = TranslationRefreshCoordinator(
            minimumProgressInterval: 1,
            now: sharedClock.now,
            execute: sharedExecutor.execute,
            schedule: sharedSchedule.schedule
        )
        sharedCoordinator.request(.initial)
        var secondMessagePresented = false
        sharedCoordinator.request(.initial, afterReload: {
            secondMessagePresented = true
        })
        sharedExecutor.completeNext()
        expect(!secondMessagePresented, "其他邮件的既有刷新不得提前启动翻译")
        expect(sharedExecutor.starts == [.initial, .initial], "新邮件必须获得自己的后续刷新")
        sharedExecutor.completeNext()
        expect(secondMessagePresented, "新邮件的刷新完成后才能启动翻译")

        let terminalClock = ManualRefreshClock()
        let terminalExecutor = ManualRefreshExecutor()
        let terminalSchedule = ManualRefreshSchedule()
        let terminalCoordinator = TranslationRefreshCoordinator(
            minimumProgressInterval: 1,
            now: terminalClock.now,
            execute: terminalExecutor.execute,
            schedule: terminalSchedule.schedule
        )
        terminalCoordinator.request(.initial)
        terminalCoordinator.request(.terminal)
        var initialAfterTerminalPresented = false
        terminalCoordinator.request(.initial, afterReload: {
            initialAfterTerminalPresented = true
        })
        terminalExecutor.completeNext()
        expect(!initialAfterTerminalPresented, "排队终态刷新不得启动另一封邮件的翻译")
        expect(terminalExecutor.starts == [.initial, .terminal], "终态刷新必须优先完成")
        terminalExecutor.completeNext()
        expect(!initialAfterTerminalPresented, "终态刷新不能替代新邮件的初始横幅刷新")
        expect(
            terminalExecutor.starts == [.initial, .terminal, .initial],
            "终态刷新后必须补发新邮件的初始刷新"
        )
        if terminalExecutor.starts.count == 3 {
            terminalExecutor.completeNext()
            expect(initialAfterTerminalPresented, "补发初始刷新结束后才能启动翻译")
        }

        let displacedClock = ManualRefreshClock()
        let displacedExecutor = ManualRefreshExecutor()
        let displacedSchedule = ManualRefreshSchedule()
        let displacedCoordinator = TranslationRefreshCoordinator(
            minimumProgressInterval: 1,
            now: displacedClock.now,
            execute: displacedExecutor.execute,
            schedule: displacedSchedule.schedule
        )
        displacedCoordinator.request(.initial)
        var displacedInitialPresented = false
        displacedCoordinator.request(.initial, afterReload: {
            displacedInitialPresented = true
        })
        displacedCoordinator.request(.terminal)
        displacedExecutor.completeNext()
        expect(!displacedInitialPresented, "被终态替换的初始刷新不得提前启动翻译")
        expect(displacedExecutor.starts == [.initial, .terminal], "终态刷新应先执行")
        displacedExecutor.completeNext()
        expect(!displacedInitialPresented, "终态刷新不能消费被替换初始刷新的回调")
        expect(
            displacedExecutor.starts == [.initial, .terminal, .initial],
            "被替换初始刷新必须在终态后补发"
        )
        if displacedExecutor.starts.count == 3 {
            displacedExecutor.completeNext()
            expect(displacedInitialPresented, "补发初始刷新完成后才允许启动翻译")
        }
        refreshCoordinator.request(.initial)
        refreshCoordinator.request(.progress)
        refreshCoordinator.request(.progress)
        expect(refreshExecutor.starts == [.initial], "刷新不得重叠")
        refreshExecutor.completeNext()
        expect(refreshSchedule.count == 1, "相邻进度刷新应合并为一个延迟任务")
        refreshClock.advance(by: 1)
        refreshSchedule.fireNext()
        expect(refreshExecutor.starts == [.initial, .progress], "合并进度应在限流窗口后刷新一次")
        refreshCoordinator.request(.terminal)
        expect(refreshExecutor.starts == [.initial, .progress], "终态刷新必须等待活跃刷新结束")
        refreshExecutor.completeNext()
        expect(refreshExecutor.starts == [.initial, .progress, .terminal], "终态刷新应在活跃刷新后立即执行")
        refreshExecutor.completeNext()

        // MARK: 结果

        if failureCount > 0 {
            fputs("\(failureCount) 个断言失败\n", stderr)
            throw NSError(domain: "CoreTests", code: 1)
        }
        print("全部测试通过")
    }
}
