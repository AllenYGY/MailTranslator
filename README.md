<p align="center">
  <img src="Resources/Icon/icon-v1-ocean-1024.png" width="160" alt="MailTranslator logo">
</p>

# MailTranslator

<p align="center">
  Apple Translation-only edition for the Mac App Store.<br>
  面向 Mac App Store 的 Apple 系统翻译专用版本。
</p>

> [简体中文](#简体中文) | [English](#english)

## 简体中文

本 README 适用于 `codex/app-store` 分支。MailTranslator 是原生 macOS MailKit 扩展，在邮件原文下方渐进显示双语译文，支持停止、续译和切换回原文。

此版本仅使用 **Apple 系统翻译**，无需 API Key。发行源码不包含第三方翻译服务端点、模型目录或密钥配置。需要多 LLM、火山引擎翻译或 Homebrew 安装的独立分发版，请查看 [`main` 分支](https://github.com/AllenYGY/MailTranslator/tree/main)。

### 系统要求与设置

- **macOS 26 或更高版本**，使用 Apple Mail。
- 先在 **系统设置 > 通用 > 语言与地区 > 翻译语言** 中下载邮件的**源语言和目标语言**。语言组合须受 Apple 系统翻译支持；仅选择目标语言不等于已下载资源。[Apple 设置说明](https://support.apple.com/guide/mac-help/intl163/mac)
- 打开 **MailTranslator**，选择目标语言并保存。
- 在 **Mail > 设置 > 扩展** 中启用 MailTranslator 对应的邮件翻译扩展，然后打开邮件并点击翻译。

### 免费试用与永久解锁

- 在应用内明确点击“免费开始 7 天试用”，并完成 App Store 的免费领取，才会开始完整试用；下载或首次打开应用不会自动开始计时。
- 试用通过**免费非消耗型 App 内购买**领取，每个 Apple 账户一次，自原始领取交易时间起持续 **7 天**。重新安装或恢复购买不会重置试用。
- 永久解锁为**一次性人民币 6 元（CNY 6）**的非消耗型 App 内购买；实际付款金额以 App Store 所在地区显示为准。
- **无订阅、无自动续费**。试用不会自动转为付费；到期后继续翻译需另行购买永久解锁。已有购买可通过“恢复购买”验证。

### 隐私与支持

翻译使用 Apple 的 Translation 框架及已下载的语言资源。目标语言配置通过本机 App Group 在主应用和扩展之间共享；译文在本机缓存，当前没有自动过期清理。应用不向开发者服务器上传邮件、配置或缓存，也不集成广告、跟踪或分析 SDK。Apple 系统服务的数据处理不等同于应用自身的数据处理，详见[本版本隐私政策](docs/privacy-policy.md)。

问题反馈与隐私支持：[MailTranslator Issues](https://github.com/AllenYGY/MailTranslator/issues)。请勿在公开 issue 中提交邮件正文或其他私人信息。

### 开发构建与 App Store 归档

需要包含 macOS 26 SDK 的 Xcode；App Store 归档还需要正确的开发团队、签名和 App Group 配置。

```sh
git clone --branch codex/app-store https://github.com/AllenYGY/MailTranslator.git
cd MailTranslator
./test.sh
./build.sh
```

`./test.sh` 运行核心逻辑、App Store 版本配置与设置界面命中测试。`./build.sh` 以 `APP_STORE` 编译，生成 `build/MailTranslator.app` 通用二进制，**保留 StoreKit 授权门控**，仅用于本地开发，不是绕过购买的独立分发包，也不是 App Store 上传产物。本地签名本身不提供 App Store 授权。

发行时在 Xcode 打开 `MailTranslator.xcodeproj`，选择 **MailTranslator** scheme 和 macOS 归档目标，执行 **Product > Archive**（Release）。在 Organizer 中验证归档，再通过 **Distribute App > App Store Connect** 上传。StoreKit 本地测试使用单独的 **StorePurchaseTests** scheme；本地测试交易不代表生产环境授权或商品已上线。

本文说明分支的实现与构建流程，不确认 App Store 上架、审核通过或隐私标签提交状态。

## English

This README covers the `codex/app-store` branch. MailTranslator is a native MailKit extension for macOS Mail. It progressively displays bilingual translations below the original message, with stop, continue and original-only controls.

This edition uses **Apple Translation only**, with no API keys. Its shipping source contains no third-party translation provider endpoints, model catalogs or credential configuration. For the direct-distribution edition with multiple LLM providers, Volcengine translation and Homebrew installation, see the [`main` branch](https://github.com/AllenYGY/MailTranslator/tree/main).

### Requirements and Setup

- **macOS 26 or later**, using Apple Mail.
- First download **both the source and target languages** in **System Settings > General > Language & Region > Translation Languages**. Apple Translation must support the language pair; selecting a target language in the app does not download its resources. [Apple settings guide](https://support.apple.com/guide/mac-help/intl163/mac)
- Open **MailTranslator**, choose the target language and save.
- Enable the MailTranslator translation extension in **Mail > Settings > Extensions**, then open a message and invoke Translate.

### Free Trial and Permanent Unlock

- Explicitly select **Start Free 7-Day Trial** in the app and complete the free App Store claim to begin full access. Downloading or first opening the app does not start the trial.
- The trial is a **free non-consumable in-app purchase**, claimable once per Apple Account. It lasts **7 days** from the original claim transaction. Reinstalling or restoring purchases does not restart it.
- Permanent unlock is a **one-time CNY 6 non-consumable in-app purchase**. The App Store price displayed for your region governs the actual payment.
- **No subscription or automatic renewal.** The trial does not automatically become a paid purchase. Continuing translation after expiry requires a separate permanent unlock; use **Restore Purchases** to verify an existing purchase.

### Privacy and Support

Translation uses Apple's Translation framework and downloaded language resources. Target-language settings are shared locally between the app and extension through an App Group. Translations are cached locally with no automatic expiry cleanup. The app does not upload messages, configuration or caches to developer servers and includes no advertising, tracking or analytics SDKs. Apple's system-service data handling is distinct from the app's own behavior; see this edition's [privacy policy](docs/privacy-policy.md).

For help or privacy questions, use [MailTranslator Issues](https://github.com/AllenYGY/MailTranslator/issues). Do not post message content or other private information in public issues.

### Development Builds and App Store Archives

Use Xcode with the macOS 26 SDK. App Store archives also require the appropriate development team, signing and App Group configuration.

```sh
git clone --branch codex/app-store https://github.com/AllenYGY/MailTranslator.git
cd MailTranslator
./test.sh
./build.sh
```

`./test.sh` runs core logic, App Store edition configuration and settings hit-testing checks. `./build.sh` compiles with `APP_STORE` and produces a universal `build/MailTranslator.app` **with StoreKit authorization gates intact**. It is a local development build, not a purchase-free direct-distribution package or an App Store upload artifact. Local signing alone does not grant App Store authorization.

For distribution, open `MailTranslator.xcodeproj` in Xcode, select the **MailTranslator** scheme and a macOS archive destination, and use **Product > Archive** (Release). Validate the archive in Organizer, then upload using **Distribute App > App Store Connect**. Use the separate **StorePurchaseTests** scheme for local StoreKit testing; local test transactions do not establish production entitlement or product availability.

This document describes the branch's implementation and build workflow, not confirmed App Store publication, review approval or privacy-label submission status.

## Acknowledgements / 致谢

MIME parsing and HTML segmentation build on ideas from [raikkonien/mailTranslatePlugin](https://github.com/raikkonien/mailTranslatePlugin) (MIT License). / MIME 解析与 HTML 分段的基础实现参考该项目。

## License

[MIT](LICENSE)
