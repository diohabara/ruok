import Foundation

final class RunStore {
    let dataDirectory: URL
    let screenshotsDirectory: URL
    let recordsURL: URL

    init(config: AppConfig) {
        self.dataDirectory = config.dataDirectory
        self.screenshotsDirectory = config.screenshotsDirectory
        self.recordsURL = config.recordsURL
    }

    func prepare() throws {
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: recordsURL.path) {
            FileManager.default.createFile(atPath: recordsURL.path, contents: nil)
        }
    }

    func append(_ record: AdviceRecord) throws {
        try prepare()
        var data = try JSONEncoder().encode(record)
        data.append(0x0A)
        let handle = try FileHandle(forWritingTo: recordsURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
    }

    func latest() -> AdviceRecord? {
        guard let text = try? String(contentsOf: recordsURL, encoding: .utf8) else {
            return nil
        }
        for line in text.components(separatedBy: .newlines).reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
                continue
            }
            if let record = try? JSONDecoder().decode(AdviceRecord.self, from: data) {
                return record
            }
        }
        return nil
    }
}
