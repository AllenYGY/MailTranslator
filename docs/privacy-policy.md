# MailTranslator Privacy Policy / 隐私政策

Effective date / 生效日期：2026-10-11

## 简体中文

MailTranslator 是 macOS Mail 的翻译扩展。本政策说明当前版本的数据处理方式。

### 邮件与翻译服务

当你请求翻译时，扩展会处理邮件正文。选择云端翻译服务时，需要翻译的文本、目标语言和相关翻译指令会发送到你配置的服务地址。该服务也会接收处理请求所需的认证信息。获取模型列表时，应用会向你配置的服务发送模型目录请求和认证信息。

OpenAI 兼容服务和火山引擎等第三方服务独立处理这些请求；其隐私政策、数据留存方式与费用由服务提供商规定。请勿把机密邮件发送到未经你信任或组织批准的服务地址。

Apple 系统翻译通过 macOS 提供的 Translation 框架运行，需要系统支持的语言资源。它不使用你配置的云端 LLM 服务地址。

### 本地保存

API 地址、模型、语言和服务认证配置保存在本机。App Store 版本的主应用和 Mail 扩展通过专用 App Group 共享配置。认证信息目前保存在受文件权限限制的 JSON 配置文件中，不是 Keychain 加密存储。

译文会保存在扩展的本地缓存中，以便再次打开邮件时使用。缓存文件名由邮件标识、服务和目标语言的哈希生成；缓存内容包含译文。缓存目前没有自动过期清理功能。

本地配置与译文缓存不会上传到开发者服务器。云端翻译请求的数据发送另见上一节。系统诊断日志可能记录运行状态和错误信息。

### 分析与控制

当前版本未集成广告、跟踪或第三方分析 SDK。你可以选择服务地址、停止当前翻译任务，并切换回原文显示。停止翻译不会撤回已经发送给服务提供商的数据，原文显示也不会删除已有缓存。

隐私问题或本地数据删除协助可通过项目支持页面联系开发者：
https://github.com/AllenYGY/MailTranslator/issues
请不要在公开 issue 中提交邮件正文、API Key 或其他私人信息。

## English

MailTranslator is a translation extension for macOS Mail. This policy describes data handling in the current version.

### Messages and Translation Services

When you request translation, the extension processes message body text. With a cloud provider, text to be translated, the target language and translation instructions are sent to the service endpoint you configure. Authentication information needed for the request is also sent to that provider. Fetching a model catalog sends a catalog request and authentication information to the configured endpoint.

Third-party providers, including OpenAI-compatible services and Volcengine, handle these requests independently. Their privacy policies, retention practices and fees apply. Do not send confidential messages to endpoints you do not trust or that your organization has not approved.

Apple Translation uses the macOS Translation framework and requires supported language resources. It does not use your configured cloud LLM endpoint.

### Local Storage

Service endpoints, models, languages and authentication configuration are stored on your Mac. The App Store app and Mail extension share configuration through a dedicated App Group. Credentials are currently stored in a JSON configuration file with restricted file permissions, not encrypted Keychain storage.

Translations are cached locally in the extension for reuse. Cache filenames are hashes derived from a message identifier, provider and target language; cache contents include translations. The cache currently has no automatic expiry cleanup.

Local configuration and translation cache files are not uploaded to developer servers. Cloud translation requests are described above. System diagnostic logs may record operational status and errors.

### Analytics and Controls

The current version includes no advertising, tracking or third-party analytics SDK. You can choose a service endpoint, stop a translation task and return to the original-only view. Stopping a task does not retract data already sent to a provider, and switching to the original view does not delete cached translations.

For privacy questions or assistance removing local data, contact the developer through the project support page:
https://github.com/AllenYGY/MailTranslator/issues
Do not include message text, API keys or other private information in public issues.
