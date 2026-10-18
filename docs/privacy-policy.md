# MailTranslator Privacy Policy / 隐私政策

Effective date / 生效日期：2026-10-19

## 简体中文

本政策适用于 MailTranslator 的 **Mac App Store 版**。此版本仅使用 Apple 系统翻译；本政策不适用于支持多种翻译服务的独立分发版。

### 邮件与 Apple 系统翻译

当你请求翻译时，扩展会处理邮件正文，并使用 macOS 的 Apple Translation 框架及已安装的源语言、目标语言资源生成译文。请先在 **系统设置 > 通用 > 语言与地区 > 翻译语言** 中下载这两种语言。

本版本仅使用 Apple 系统翻译，不连接第三方翻译服务端点、不请求模型目录，也不要求或保存 API 密钥。邮件正文不会发送到第三方 LLM 或火山引擎翻译服务，也不会上传到开发者服务器。

Apple 翻译属于系统服务。Apple 的框架文档说明其可能收集 API 使用与性能指标；本政策不承诺 Apple 不处理任何系统服务数据。语言资源下载、系统诊断及其他 Apple 服务的数据处理由 Apple 控制，参见 [Apple Translation 文档](https://developer.apple.com/documentation/translation/translationsession)及 [Apple 隐私政策](https://www.apple.com/legal/privacy/)。

### 本地配置与缓存

主应用和 Mail 扩展通过专用 **App Group** 共享本机的目标语言配置。配置为 JSON 文件，使用受限文件权限；本版本不保存第三方服务地址、模型目录或服务密钥。

译文保存在扩展沙盒内的本地缓存中，以便再次打开邮件时使用。缓存文件名由邮件标识、翻译引擎和目标语言的哈希生成，缓存内容包含译文及引擎、目标语言信息。文件名使用哈希不等于缓存内容已加密。缓存当前**没有自动过期清理机制**。

应用不向开发者服务器上传配置或译文缓存。系统诊断日志可能记录运行状态和错误信息。

### 免费试用与购买

免费 7 天试用由用户明确领取免费非消耗型 App 内购买后开始；永久解锁为另行进行的一次性非消耗型购买，无订阅或自动续费。

商品查询、领取试用、购买、恢复购买与授权验证通过 **Apple StoreKit / App Store** 处理。应用使用 Apple 验证的应用及购买交易信息，包括商品标识、原始购买时间和撤销状态，以判断试用期限和永久解锁资格。付款及 Apple 账户信息由 Apple 按其政策处理；应用不收集支付卡信息，也没有开发者购买验证服务器。

### 分析、控制与联系

本版本不集成广告、跟踪或分析 SDK，也不运行开发者数据收集或翻译服务器。此说明不排除 Apple 系统服务自身的数据处理。

你可以更改目标语言、停止翻译任务或切换回原文。停止任务或显示原文不会删除已有译文缓存；重新安装或恢复购买不会重置 Apple 交易记录中的试用起始时间。

隐私问题或本地数据删除协助，请通过 [MailTranslator 支持页面](https://github.com/AllenYGY/MailTranslator/issues)联系开发者。请不要在公开 issue 中提交邮件正文、购买凭证或其他私人信息。通过 GitHub 联系时，你主动提供的信息也由 GitHub 按其政策处理。

## English

This policy applies to the **Mac App Store edition** of MailTranslator. This edition uses only Apple Translation; this policy does not cover the multi-provider direct-distribution edition.

### Messages and Apple Translation

When you request translation, the extension processes message body text using the macOS Apple Translation framework and installed source- and target-language resources. Download both languages first in **System Settings > General > Language & Region > Translation Languages**.

This edition uses only Apple Translation. It does not connect to third-party translation provider endpoints, request model catalogs, or require or store API keys. It does not send message bodies to third-party LLM or Volcengine translation services or upload them to developer servers.

Apple Translation is a system service. Apple's framework documentation describes possible collection of API usage and performance metrics; this policy does not promise that Apple processes no system-service data. Apple controls data handling for language downloads, system diagnostics and other Apple services. See the [Apple Translation documentation](https://developer.apple.com/documentation/translation/translationsession) and [Apple Privacy Policy](https://www.apple.com/legal/privacy/).

### Local Configuration and Cache

The app and Mail extension share target-language settings locally through a dedicated **App Group**. Configuration is stored as JSON with restricted file permissions. This edition does not store third-party service endpoints, model catalogs or service keys.

Translations are cached locally inside the extension's sandbox for reuse. Cache filenames are hashes derived from a message identifier, translation engine and target language. Cache contents include translations, engine and target-language information. Hashed filenames do not mean the contents are encrypted. The cache currently has **no automatic expiry cleanup**.

The app does not upload configuration or translation caches to developer servers. System diagnostic logs may record operational status and errors.

### Free Trial and Purchases

The free 7-day trial begins when you explicitly claim a free non-consumable in-app purchase. Permanent unlock is a separate one-time non-consumable purchase, with no subscription or automatic renewal.

Product queries, trial claims, purchases, restoration and authorization checks use **Apple StoreKit / App Store**. The app uses Apple-verified app and purchase transaction information, including product identifiers, original purchase dates and revocation status, to determine trial and permanent-unlock eligibility. Apple handles payment and Apple Account information under its policies. The app does not collect payment-card information or use a developer-operated purchase-verification server.

### Analytics, Controls and Contact

This edition includes no advertising, tracking or analytics SDKs and operates no developer data-collection or translation server. This does not exclude data handling by Apple's own system services.

You can change the target language, stop translation or return to the original-only view. Stopping a task or displaying the original does not delete cached translations. Reinstalling or restoring purchases does not reset the trial's original claim date in Apple transaction records.

For privacy questions or help removing local data, contact the developer through [MailTranslator Support](https://github.com/AllenYGY/MailTranslator/issues). Do not post message content, purchase receipts or other private information in public issues. Information you choose to provide through GitHub is also handled by GitHub under its policies.
