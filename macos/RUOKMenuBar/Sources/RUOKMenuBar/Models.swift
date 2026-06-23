import Foundation

struct AdviceRecord: Codable {
    let id: String
    let createdAt: String
    let screenshotPath: String
    let previousScreenshotPath: String?
    let changedPercent: Double
    let rms: Double
    let summary: String
    let advice: String
    let model: String

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case screenshotPath = "screenshot_path"
        case previousScreenshotPath = "previous_screenshot_path"
        case changedPercent = "changed_percent"
        case rms
        case summary
        case advice
        case model
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(screenshotPath, forKey: .screenshotPath)
        if let previousScreenshotPath {
            try container.encode(previousScreenshotPath, forKey: .previousScreenshotPath)
        } else {
            try container.encodeNil(forKey: .previousScreenshotPath)
        }
        try container.encode(changedPercent, forKey: .changedPercent)
        try container.encode(rms, forKey: .rms)
        try container.encode(summary, forKey: .summary)
        try container.encode(advice, forKey: .advice)
        try container.encode(model, forKey: .model)
    }
}

struct NotificationMessage {
    let title: String
    let subtitle: String
    let body: String
}
