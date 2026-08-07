# MailTranslator

macOS Apple Mail 翻译扩展（MailKit）。支持多翻译引擎、并发翻译、渐进式双语对照渲染。

## 特性

- **多翻译引擎**
  - OpenAI 兼容 LLM（`/v1/chat/completions`，SSE 流式，支持 DeepSeek / 豆包 / 通义 / Kimi / Ollama 等任意兼容端点）
  - 火山翻译（火山引擎机器翻译，`TextList` 批量接口，每月 200 万字符免费额度）
  - Apple 系统翻译（设备端、免费，macOS 14+）
- **快**：批次并发请求 + LLM SSE 流式 + 每批完成即刷新邮件显示（渐进渲染），重开邮件走本地缓存秒出
- 目标语言可配置（简中/繁中/英/日/韩/法/德/西/俄）
- 隐私：只有点击"翻译"后才会把当前邮件正文发送给你自己配置的服务

## 系统要求

- macOS 14 或更高版本
- 构建：Xcode Command Line Tools（`xcode-select --install`）

## 构建 / 测试 / 安装

```sh
./build.sh    # 生成 build/MailTranslator.app（通用二进制）
./test.sh     # 核心逻辑单元测试
./install.sh  # 安装到 /Applications 并注册扩展（会重启 Mail，请先保存草稿）
```

安装后在 **Mail > 设置 > 扩展** 勾选"邮件翻译"，打开 MailTranslator.app 填写引擎配置。

## 配置 LLM Provider

在 MailTranslator 设置中选择 **LLM** 后，可以从 OpenAI、DeepSeek、Kimi、通义千问、豆包（火山方舟）、Ollama 等预设开始，也可以选择 **自定义** 并填写任意 OpenAI 兼容 API 地址。

每个预设都是独立的 provider 配置，会分别保存 API 地址、API Key、已选模型和已获取的模型列表。切换 provider 不会复用或覆盖其他 provider 的 Key；旧版本共享的 `openAI` 配置会在读取时兼容迁移到匹配的 provider，并在下一次保存时写成新格式。

填写 API 地址和 API Key 后点击 **获取模型**，应用会尝试调用兼容服务的 `GET /models` 接口，并把返回结果放入可搜索、可编辑的模型下拉框。模型框始终允许手动输入，因此未提供标准模型目录的服务（例如部分通义或火山方舟部署）仍可直接填写控制台给出的模型 ID。

远程 API 地址必须使用 HTTPS；本机和私网服务可使用 HTTP，例如 Ollama 的 `http://localhost:11434/v1`。

## 命令行调试

```sh
build/tmtest parse|segments|translate|rewrite <email.eml>
```

## 致谢

MIME 解析、HTML 分段等基础代码改编自 [raikkonien/mailTranslatePlugin](https://github.com/raikkonien/mailTranslatePlugin)（MIT License）。
多引擎架构参考 [tisfeng/Easydict](https://github.com/tisfeng/Easydict)（GPL-3.0，仅参考设计，未复制代码）。

## License

MIT
