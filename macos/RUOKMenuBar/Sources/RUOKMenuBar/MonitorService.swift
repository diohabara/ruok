import Foundation

actor MonitorService {
    private let store: RunStore
    private let capturer: ScreenshotCapturer
    private let advisor: OllamaVisionAdvisor
    private let notificationManager: NotificationManager
    private let logger: AppLogger
    private var running = false

    init(
        store: RunStore,
        capturer: ScreenshotCapturer,
        advisor: OllamaVisionAdvisor,
        notificationManager: NotificationManager,
        logger: AppLogger
    ) {
        self.store = store
        self.capturer = capturer
        self.advisor = advisor
        self.notificationManager = notificationManager
        self.logger = logger
    }

    func runOnce() async throws -> AdviceRecord {
        guard !running else {
            throw MonitorServiceError.alreadyRunning
        }
        running = true
        defer {
            running = false
        }

        try Task.checkCancellation()
        try store.prepare()
        compressExistingScreenshots()

        let createdAt = Date()
        let recordID = makeRecordID(date: createdAt)
        let currentURL = store.screenshotsDirectory.appendingPathComponent("\(recordID).png")
        let latest = store.latest()
        let previousURL = latest.flatMap { record -> URL? in
            guard !record.screenshotPath.isEmpty else {
                return nil
            }
            let url = screenshotURL(record.screenshotPath)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        try Task.checkCancellation()
        try capturer.capture(to: currentURL)
        let delta = try ImageDiffer.compare(previousURL: previousURL, currentURL: currentURL)

        try Task.checkCancellation()
        let advice: String
        let model: String
        do {
            advice = try await advisor.advise(
                previousURL: previousURL,
                currentURL: currentURL,
                delta: delta
            )
            model = advisor.model
        } catch {
            try Task.checkCancellation()
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            advice = fallbackAdvice(delta: delta, error: error)
            model = "fallback:\(advisor.model)"
        }

        let record = AdviceRecord(
            id: recordID,
            createdAt: ISO8601DateFormatter().string(from: createdAt),
            screenshotPath: relativePath(currentURL, base: store.dataDirectory),
            previousScreenshotPath: previousURL.map { relativePath($0, base: store.dataDirectory) },
            changedPercent: delta.changedPercent,
            rms: delta.rms,
            summary: delta.summary,
            advice: advice,
            model: model
        )
        try Task.checkCancellation()
        try store.append(record)
        try Task.checkCancellation()
        await notificationManager.notify(AdviceFormatter.notificationMessage(from: record))
        return record
    }

    private func compressExistingScreenshots() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: store.screenshotsDirectory,
                includingPropertiesForKeys: nil
            )
            var compressed = 0
            for file in files where file.pathExtension.lowercased() == "png" {
                if try ImageTools.compressImageFile(file, maxEdge: capturer.maxEdge) {
                    compressed += 1
                }
            }
            if compressed > 0 {
                logger.write("Compressed \(compressed) stored screenshots")
            }
        } catch {
            logger.write("Screenshot compression skipped: \(error.localizedDescription)")
        }
    }

    private func makeRecordID(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "\(formatter.string(from: date))-\(UUID().uuidString.prefix(8).lowercased())"
    }

    private func relativePath(_ url: URL, base: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(basePath + "/") {
            return String(path.dropFirst(basePath.count + 1))
        }
        return path
    }

    private func screenshotURL(_ path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        return store.dataDirectory.appendingPathComponent(expanded)
    }

    private func fallbackAdvice(delta: ImageDelta, error: Error) -> String {
        "\(delta.summary)\n\n"
            + "ローカルLLMから助言を取得できませんでした。"
            + " Ollamaの起動、モデル名、画面収録権限を確認してください。詳細: \(error.localizedDescription)\n\n"
            + "次の一手: 直近5分で進めたい作業を1つだけ決めてください。"
    }
}

enum MonitorServiceError: LocalizedError {
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "すでに確認処理が実行中です。"
        }
    }
}
