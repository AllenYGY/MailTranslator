import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        let controller = SettingsViewController()
        let window = NSWindow(contentViewController: controller)
        window.title = "MailTranslator"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isRestorable = ApplicationStatePolicy.restoresSettingsControls
        window.setContentSize(NSSize(width: 660, height: 500))
        window.contentMinSize = NSSize(width: 620, height: 500)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldSaveSecureApplicationState(_ app: NSApplication) -> Bool {
        ApplicationStatePolicy.restoresSettingsControls
    }

    func applicationShouldRestoreSecureApplicationState(_ app: NSApplication) -> Bool {
        ApplicationStatePolicy.restoresSettingsControls
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        mainMenu.autoenablesItems = true

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "关于 MailTranslator",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "退出 MailTranslator",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
