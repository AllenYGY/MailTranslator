import AppKit
import ImageIO
import UniformTypeIdentifiers

// Run from the repository root. Inputs are unmodified CUA captures of build 4.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("docs/app-store/screenshots")
let input = root.appendingPathComponent("docs/app-store/captures").path
let captures = [
    ("01-bilingual", input + "/MailTranslator-mail-bilingual-20261011.png", CGRect(x: 0, y: 104, width: 2596, height: 856)),
    ("02-original", input + "/MailTranslator-mail-original-20261011.png", CGRect(x: 0, y: 104, width: 2596, height: 616)),
    ("03-providers", input + "/MailTranslator-llm-config-20261011.png", CGRect(x: 0, y: 64, width: 1440, height: 1360)),
    ("04-unlock", input + "/MailTranslator-capture-retry-20261011.png", CGRect(x: 0, y: 64, width: 1440, height: 1110))
]
let copy: [String: [(String, String, String)]] = [
    "zh-Hans": [
        ("原文与译文，一起阅读", "在 macOS Mail 中，将译文显示在原文下方。", "真实 Mail 界面 · 虚构示例邮件"),
        ("随时回到原文", "原文与双语视图切换，无需重新选择邮件。", "保留阅读上下文 · 已生成的译文仍可查看"),
        ("选择自己的翻译服务", "独立配置 API 地址、密钥与模型。", "支持兼容 LLM 与火山翻译 · 第三方服务费用另计"),
        ("试用 7 天，一次解锁", "免费下载，完整试用后可一次性永久解锁。", "中国区永久解锁 ¥6 · Apple 翻译需 macOS 26+ 及语言资源")
    ],
    "en": [
        ("Read both languages together", "Translations appear beneath the original text in macOS Mail.", "Real Mail interface · Fictional sample message"),
        ("Return to the original", "Switch between original and bilingual views without reselecting the message.", "Keep your reading context · Previously translated text stays available"),
        ("Choose your translation service", "Configure each provider's endpoint, key, and model.", "Compatible LLMs and Volcengine · Third-party service fees are separate"),
        ("Try 7 days. Unlock once.", "Free download with a full trial and a one-time permanent unlock.", "No subscription · Apple Translation requires macOS 26+ and language resources")
    ]
]
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}
let ink = color(0.08, 0.15, 0.19)
let teal = color(0.00, 0.43, 0.45)
func text(_ value: String, x: CGFloat, top: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight, foreground: NSColor) throws {
    let attr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: foreground, .kern: 0]
    let string = NSAttributedString(string: value, attributes: attr)
    let bounds = string.boundingRect(with: NSSize(width: width, height: 300), options: [.usesLineFragmentOrigin, .usesFontLeading])
    guard bounds.height < size * 2.5 else { throw NSError(domain: "ArtworkTextOverflow", code: 1) }
    string.draw(with: CGRect(x: x, y: 1600 - top - ceil(bounds.height), width: width, height: ceil(bounds.height)), options: [.usesLineFragmentOrigin, .usesFontLeading])
}
var manifest: [[String: Any]] = []
for language in ["zh-Hans", "en"] {
    let directory = output.appendingPathComponent(language)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for (index, capture) in captures.enumerated() {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: capture.1) as CFURL, nil),
              let original = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let cropped = original.cropping(to: capture.2),
              let context = CGContext(data: nil, width: 2560, height: 1600, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("Missing capture: \(capture.1)") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        color(0.94, 0.97, 0.98).setFill()
        CGRect(x: 0, y: 0, width: 2560, height: 1600).fill()
        color(0.88, 0.94, 0.94).setFill()
        CGRect(x: 0, y: 0, width: 2560, height: 100).fill()
        let logo = NSImage(contentsOf: root.appendingPathComponent("Resources/Icon/icon-v1-ocean-1024.png"))!
        logo.draw(in: CGRect(x: 120, y: 1444, width: 88, height: 88))
        try text("MailTranslator", x: 234, top: 86, width: 1500, size: 44, weight: .semibold, foreground: ink)
        try text(String(format: "%02d / 04", index + 1), x: 2240, top: 94, width: 230, size: 30, weight: .medium, foreground: teal)
        let words = copy[language]![index]
        try text(words.0, x: 120, top: 206, width: 2330, size: language == "en" ? 96 : 104, weight: .bold, foreground: ink)
        try text(words.1, x: 124, top: 344, width: 2310, size: 38, weight: .regular, foreground: teal)
        let available = CGSize(width: 2320, height: 1020)
        let scale = min(available.width / CGFloat(cropped.width), available.height / CGFloat(cropped.height))
        let size = CGSize(width: CGFloat(cropped.width) * scale, height: CGFloat(cropped.height) * scale)
        let frame = CGRect(x: (2560 - size.width) / 2, y: 1600 - 448 - size.height, width: size.width, height: size.height)
        context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: NSColor.black.withAlphaComponent(0.12).cgColor)
        context.draw(cropped, in: frame)
        context.setShadow(offset: .zero, blur: 0, color: nil)
        try text(words.2, x: 120, top: 1532, width: 2330, size: 27, weight: .regular, foreground: ink)
        NSGraphicsContext.restoreGraphicsState()
        let destinationURL = directory.appendingPathComponent(capture.0 + ".png")
        guard let raster = context.makeImage(), let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("Cannot export") }
        CGImageDestinationAddImage(destination, raster, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("Cannot save") }
        manifest.append(["locale": language, "file": "screenshots/\(language)/\(capture.0).png", "capture": capture.1, "crop": [capture.2.origin.x, capture.2.origin.y, capture.2.width, capture.2.height], "size": [2560, 1600], "build": 4, "alpha": false])
        print(destinationURL.path)
    }
}
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("docs/app-store/artwork-manifest.json"))
