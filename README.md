<p align="center">
  <img src="Resources/Icon/icon-v1-ocean-1024.png" width="160" alt="MailTranslator logo">
</p>

# MailTranslator

> Website / Homebrew edition: `codex/direct-distribution`. Full provider support,
> no StoreKit gate. Apple-only App Store edition: `codex/app-store`.
> [Distribution maintenance](docs/distribution-branches.md).

<p align="center">
  macOS Mail translation extension with Apple Translation, Volcengine, and OpenAI-compatible LLM providers.<br>
  为 macOS Mail 打造的翻译扩展，支持 Apple 系统翻译、火山翻译和 OpenAI 兼容 LLM。
</p>

> [English](#english) | [简体中文](#简体中文)

## 简体中文

MailTranslator 是一个原生 macOS MailKit 扩展。阅读邮件时点击翻译，译文会以渐进式双语内容显示在原文下方；翻译任务支持停止、续译和只看原文。

### 功能

- **多翻译服务**
  - Apple 系统翻译：设备端能力，适合无需配置 API 的场景。
  - 火山翻译：使用火山引擎机器翻译 `TextList` 批量接口。
  - OpenAI 兼容 LLM：支持 OpenAI、DeepSeek、Kimi、通义千问、豆包（火山方舟）、Ollama 和自定义兼容端点。
- **渐进式双语阅读**：邮件分段并发翻译，每完成一批便刷新显示，不必等待全文完成。
- **翻译控制**：翻译中可停止；完成后可继续未完成部分，也可切换为只看原文。
- **独立 Provider 配置**：每个 LLM 预设分别保存 API 地址、API Key、模型和模型列表，切换服务不会覆盖其他服务的凭据。
- **模型发现与手动输入**：兼容服务可通过 `GET /models` 获取模型；不提供标准目录的服务仍可直接输入模型 ID。
- **本地缓存**：再次打开已经翻译过的邮件时优先使用本地结果。

### 系统要求

- macOS 14 Sonoma 或更高版本
- 使用源码构建时需要 Xcode Command Line Tools

### 通过 Homebrew 安装

```sh
brew tap AllenYGY/tap
brew trust allenygy/tap
brew install --cask mailtranslator
```

`brew trust` 是 Homebrew 6 对第三方 Tap 的显式信任要求，只需执行一次。

安装后：

1. 打开 **MailTranslator**，选择翻译服务并完成配置。
2. 打开 **Mail > 设置 > 扩展**，启用“邮件翻译”。
3. 在 Mail 中打开邮件并点击翻译操作。

### 配置翻译服务

#### Apple 系统翻译

选择“Apple 系统翻译”即可使用，无需填写 Key。系统会在支持的语言组合中使用设备翻译能力。

#### 火山翻译

选择“火山翻译”，填写火山引擎控制台提供的 Access Key ID 和 Secret Access Key，并选择目标语言。

#### OpenAI 兼容 LLM

1. 选择 **LLM**，再选择预设服务或“自定义”。
2. 填写 API 地址与 API Key。
3. 点击“获取模型”，或直接填写模型 ID。
4. 选择目标语言并保存。

远程 API 地址必须使用 HTTPS。本机或私网服务可以使用 HTTP，例如 Ollama 的 `http://localhost:11434/v1`。

### 隐私

只有在你点击翻译后，当前邮件正文才会发送到你选择的翻译服务。Apple 系统翻译不需要配置第三方密钥；使用云端翻译或 LLM 时，请根据对应服务的隐私政策决定是否翻译敏感内容。

### 从源码构建

```sh
git clone https://github.com/AllenYGY/ExtentionforMail.git MailTranslator
cd MailTranslator

./test.sh
./build.sh
./install.sh
```

| 命令 | 作用 |
| --- | --- |
| `./test.sh` | 运行核心逻辑与设置界面命中测试。 |
| `./build.sh` | 构建通用二进制应用到 `build/MailTranslator.app`。 |
| `./install.sh` | 安装到 `/Applications` 并注册扩展；会重启 Mail。 |

命令行调试工具：

```sh
build/tmtest parse|segments|translate|rewrite <email.eml>
```

### 致谢

- MIME 解析和 HTML 分段的基础实现参考 [raikkonien/mailTranslatePlugin](https://github.com/raikkonien/mailTranslatePlugin)（MIT License）。
- 多 Provider 设计参考 [tisfeng/Easydict](https://github.com/tisfeng/Easydict)（GPL-3.0，仅参考设计，未复制代码）。

## English

MailTranslator is a native MailKit extension for macOS Mail. Click Translate while reading a message to show a progressive bilingual version below the original. Translation jobs can be stopped, continued, or switched back to the original-only view.

### Highlights

- **Multiple translation providers**
  - Apple Translation for on-device translation without API setup.
  - Volcengine Machine Translation through the batch `TextList` API.
  - OpenAI-compatible LLMs, including OpenAI, DeepSeek, Kimi, DashScope, Doubao Ark, Ollama, and custom compatible endpoints.
- **Progressive bilingual reading**: message segments translate concurrently and appear as batches complete.
- **Translation controls**: stop an active job, continue incomplete segments, or switch to the original-only view.
- **Isolated provider profiles**: every LLM preset keeps its own endpoint, API key, selected model, and model catalog.
- **Model discovery with manual fallback**: fetch models from `GET /models`, or enter a model ID directly when a provider has no standard catalog.
- **Local cache**: previously translated messages reopen from local results when available.

### Requirements

- macOS 14 Sonoma or later
- Xcode Command Line Tools for source builds

### Install with Homebrew

```sh
brew tap AllenYGY/tap
brew trust allenygy/tap
brew install --cask mailtranslator
```

Homebrew 6 requires an explicit one-time trust action for third-party taps.

After installation:

1. Open **MailTranslator** and configure a translation provider.
2. In **Mail > Settings > Extensions**, enable “Mail Translator”.
3. Open a message in Mail and invoke the translation action.

### Configure a Provider

#### Apple Translation

Select **Apple Translation**. No key is required; the extension uses the translation capabilities available on the device.

#### Volcengine Machine Translation

Select **Volcengine Translation**, enter the Access Key ID and Secret Access Key from the Volcengine console, then choose the target language.

#### OpenAI-Compatible LLM

1. Select **LLM**, then choose a preset or **Custom**.
2. Enter the API base URL and API key.
3. Select **Fetch Models**, or enter a model ID directly.
4. Choose a target language and save.

Remote endpoints must use HTTPS. HTTP is allowed for local or private-network services, such as Ollama at `http://localhost:11434/v1`.

### Privacy

MailTranslator sends message content to a selected provider only after you request a translation. Apple Translation needs no third-party credentials. When using a cloud service or LLM, decide whether to translate sensitive content according to that provider's privacy policy.

### Build from Source

```sh
git clone https://github.com/AllenYGY/ExtentionforMail.git MailTranslator
cd MailTranslator

./test.sh
./build.sh
./install.sh
```

| Command | Purpose |
| --- | --- |
| `./test.sh` | Runs the core logic and settings hit-testing checks. |
| `./build.sh` | Builds a universal app at `build/MailTranslator.app`. |
| `./install.sh` | Installs to `/Applications` and registers the extension; Mail restarts. |

CLI debugging tool:

```sh
build/tmtest parse|segments|translate|rewrite <email.eml>
```

### Acknowledgements

- MIME parsing and HTML segmentation build on ideas from [raikkonien/mailTranslatePlugin](https://github.com/raikkonien/mailTranslatePlugin) (MIT License).
- The multi-provider architecture takes design inspiration from [tisfeng/Easydict](https://github.com/tisfeng/Easydict) (GPL-3.0; no code copied).

## License

[MIT](LICENSE)
