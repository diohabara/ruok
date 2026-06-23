import Foundation

enum AdviceFormatter {
    static func notificationMessage(from record: AdviceRecord) -> NotificationMessage {
        let isFallback = record.model.hasPrefix("fallback:")
        let sections = extractSections(record.advice)
        let title: String
        if isFallback {
            title = "Ollama接続を確認しましょう"
        } else if let nextAction = sections["次の一手"], !nextAction.isEmpty {
            title = compactTitle(nextAction)
        } else {
            title = "次の小さな行動を決めましょう"
        }

        let body = compact(formatBody(record.advice, sections: sections, preserveDiagnostics: isFallback), limit: 260)
        let subtitle = "\(record.summary) · \(String(format: "%.1f", record.changedPercent))% · \(modelLabel(record.model))"
        return NotificationMessage(title: title, subtitle: subtitle, body: body)
    }

    private static func formatBody(
        _ advice: String,
        sections: [String: String],
        preserveDiagnostics: Bool
    ) -> String {
        if preserveDiagnostics {
            var lines = nonemptyLines(advice).filter {
                $0.contains("ローカルLLM") || $0.contains("詳細:")
            }
            if let nextAction = sections["次の一手"] {
                lines.append("次の一手: \(nextAction)")
            }
            return lines.isEmpty ? advice : lines.joined(separator: "\n")
        }

        guard let nextAction = sections["次の一手"] else {
            return advice
        }

        var lines = ["次の一手: \(nextAction)"]
        if let situation = sections["状況"] {
            lines.append("状況: \(situation)")
        }
        if let caution = sections["注意"] {
            lines.append("注意: \(caution)")
        }
        return lines.joined(separator: "\n")
    }

    static func extractSections(_ advice: String) -> [String: String] {
        var sections: [String: String] = [:]
        for rawLine in advice.components(separatedBy: .newlines) {
            let line = stripNumberPrefix(rawLine.trimmingCharacters(in: .whitespacesAndNewlines))
            for label in ["状況", "注意", "次の一手"] {
                if let value = valueAfterLabel(label, in: line) {
                    sections[label] = value
                    break
                }
            }
        }
        return sections
    }

    private static func stripNumberPrefix(_ line: String) -> String {
        var scalars = line.unicodeScalars[...]
        while let first = scalars.first, CharacterSet.decimalDigits.contains(first) {
            scalars.removeFirst()
        }
        if let first = scalars.first, first == "." || first == ")" || first == " " {
            scalars.removeFirst()
        }
        if let first = scalars.first, first == " " {
            scalars.removeFirst()
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func valueAfterLabel(_ label: String, in line: String) -> String? {
        for separator in [":", "："] {
            let prefix = "\(label)\(separator)"
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func compactTitle(_ text: String, limit: Int = 34) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。.!！"))
        if trimmed.count <= limit {
            return trimmed
        }
        return String(trimmed.prefix(limit - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func compact(_ text: String, limit: Int) -> String {
        let normalized = nonemptyLines(text).joined(separator: "\n")
        if normalized.count <= limit {
            return normalized
        }
        return String(normalized.prefix(limit - 3)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func nonemptyLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func modelLabel(_ model: String) -> String {
        model.hasPrefix("fallback:") ? "LLM未接続" : model
    }
}
