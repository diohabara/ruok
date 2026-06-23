import Foundation

struct AppConfig {
    let intervalSeconds: TimeInterval
    let model: String
    let ollamaEndpoint: URL
    let maxScreenshotEdge: Int
    let dataDirectory: URL
    let screenshotsDirectory: URL
    let recordsURL: URL
    let logURL: URL

    static func load() -> AppConfig {
        let environment = ProcessInfo.processInfo.environment
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        let library = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")

        let dataDirectory = environment["RUOK_DATA_DIR"].flatMap(pathURL)
            ?? applicationSupport.appendingPathComponent("RUOK/data", isDirectory: true)
        let logDirectory = library.appendingPathComponent("Logs/RUOK", isDirectory: true)

        let endpoint = URL(
            string: environment["RUOK_OLLAMA_ENDPOINT"] ?? "http://127.0.0.1:11434"
        ) ?? URL(string: "http://127.0.0.1:11434")!

        return AppConfig(
            intervalSeconds: positiveDouble(environment["RUOK_INTERVAL_SECONDS"], defaultValue: 300),
            model: environment["RUOK_OLLAMA_MODEL"] ?? "qwen2.5vl:7b",
            ollamaEndpoint: endpoint,
            maxScreenshotEdge: positiveInt(environment["RUOK_MAX_SCREENSHOT_EDGE"], defaultValue: 1600),
            dataDirectory: dataDirectory,
            screenshotsDirectory: dataDirectory.appendingPathComponent("screenshots", isDirectory: true),
            recordsURL: dataDirectory.appendingPathComponent("records.jsonl"),
            logURL: logDirectory.appendingPathComponent("ruok.menubar.log")
        )
    }

    private static func positiveInt(_ value: String?, defaultValue: Int) -> Int {
        guard let value, let intValue = Int(value), intValue > 0 else {
            return defaultValue
        }
        return intValue
    }

    private static func positiveDouble(_ value: String?, defaultValue: Double) -> Double {
        guard let value, let doubleValue = Double(value), doubleValue > 0 else {
            return defaultValue
        }
        return doubleValue
    }

    private static func pathURL(_ value: String) -> URL? {
        let expanded = (value as NSString).expandingTildeInPath
        guard !expanded.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }
}
