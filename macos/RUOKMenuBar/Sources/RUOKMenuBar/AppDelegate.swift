import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = AppConfig.load()
    private lazy var logger = AppLogger(logURL: config.logURL)
    private lazy var notificationManager = NotificationManager(logger: logger)
    private lazy var monitor = MonitorController(
        service: MonitorService(
            store: RunStore(config: config),
            capturer: ScreenshotCapturer(maxEdge: config.maxScreenshotEdge),
            advisor: OllamaVisionAdvisor(model: config.model, endpoint: config.ollamaEndpoint),
            notificationManager: notificationManager,
            logger: logger
        ),
        config: config,
        logger: logger
    )

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "停止中", action: nil, keyEquivalent: "")
    private let lastResultMenuItem = NSMenuItem(title: "まだ実行していません", action: nil, keyEquivalent: "")
    private let startMenuItem = NSMenuItem(title: "開始", action: #selector(startMonitor), keyEquivalent: "s")
    private let stopMenuItem = NSMenuItem(title: "停止", action: #selector(stopMonitor), keyEquivalent: "x")
    private let runOnceMenuItem = NSMenuItem(title: "今すぐ1回実行", action: #selector(runOnce), keyEquivalent: "r")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        logger.write("RUOK Swift menu bar app launched")
        notificationManager.requestAuthorization()
        monitor.onStatusChange = { [weak self] in
            self?.refreshMenu()
        }

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "RUOK") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "RUOK"
            }
        }

        startMenuItem.target = self
        stopMenuItem.target = self
        runOnceMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(lastResultMenuItem)
        menu.addItem(.separator())
        menu.addItem(startMenuItem)
        menu.addItem(stopMenuItem)
        menu.addItem(runOnceMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "データフォルダを開く", action: #selector(openDataFolder), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "ログを開く", action: #selector(openLogFile), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }

        statusItem.menu = menu
        refreshMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stopAll()
        logger.write("RUOK Swift menu bar app terminated")
    }

    @objc private func startMonitor() {
        monitor.start()
        refreshMenu()
    }

    @objc private func stopMonitor() {
        monitor.stop()
        refreshMenu()
    }

    @objc private func runOnce() {
        monitor.runOnce()
        refreshMenu()
    }

    @objc private func openDataFolder() {
        ensureDirectory(config.dataDirectory)
        NSWorkspace.shared.open(config.dataDirectory)
    }

    @objc private func openLogFile() {
        logger.ensureLogFile()
        NSWorkspace.shared.open(config.logURL)
    }

    @objc private func quit() {
        monitor.stopAll()
        NSApp.terminate(nil)
    }

    private func refreshMenu() {
        statusMenuItem.title = monitor.statusText
        lastResultMenuItem.title = monitor.lastResultText
        startMenuItem.isEnabled = !monitor.isRunning && !monitor.isChecking
        stopMenuItem.isEnabled = monitor.isRunning
        runOnceMenuItem.isEnabled = !monitor.isChecking
    }

    private func ensureDirectory(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            logger.write("Failed to create directory \(url.path): \(error.localizedDescription)")
        }
    }
}
