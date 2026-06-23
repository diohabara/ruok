import Foundation

final class AppLogger {
    let logURL: URL
    private let queue = DispatchQueue(label: "io.github.diohabara.ruok.menubar.logger")

    init(logURL: URL) {
        self.logURL = logURL
    }

    func write(_ message: String) {
        queue.async {
            self.writeSync(message)
        }
    }

    func ensureLogFile() {
        queue.sync {
            self.createLogFileIfNeeded()
        }
    }

    private func writeSync(_ message: String) {
        createLogFileIfNeeded()
        let line = "[RUOK] \(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }
        do {
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            NSLog("RUOK log write failed: \(error.localizedDescription)")
        }
    }

    private func createLogFileIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
        } catch {
            NSLog("RUOK log setup failed: \(error.localizedDescription)")
        }
    }
}
