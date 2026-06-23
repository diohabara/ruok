import Foundation

final class OllamaVisionAdvisor {
    let model: String
    private let endpoint: URL
    private let session: URLSession

    init(model: String, endpoint: URL) {
        self.model = model
        self.endpoint = endpoint
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 150
        self.session = URLSession(configuration: configuration)
    }

    func advise(previousURL: URL?, currentURL: URL, delta: ImageDelta) async throws -> String {
        var images: [String] = []
        if let previousURL {
            images.append(try Data(contentsOf: previousURL).base64EncodedString())
        }
        images.append(try Data(contentsOf: currentURL).base64EncodedString())

        let payload = ChatPayload(
            model: model,
            stream: false,
            messages: [
                ChatMessage(role: "user", content: prompt(delta: delta), images: images)
            ]
        )

        var request = URLRequest(url: endpoint.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw OllamaError.badResponse
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        if let content = decoded.message?.content.trimmingCharacters(in: .whitespacesAndNewlines),
           !content.isEmpty {
            return content
        }
        if let response = decoded.response?.trimmingCharacters(in: .whitespacesAndNewlines),
           !response.isEmpty {
            return response
        }
        throw OllamaError.missingContent
    }

    private func prompt(delta: ImageDelta) -> String {
        """
        あなたは作業中の画面を5分ごとに見守るローカルアシスタントです。
        添付画像は、前回のスクリーンショット、今回のスクリーンショットの順です。画像が1枚だけの場合は初回チェックです。

        画像差分: 変化率 \(String(format: "%.1f", delta.changedPercent))%, RMS \(String(format: "%.1f", delta.rms))。機械的な要約: \(delta.summary)

        日本語で、次の形式で短く返してください。
        1. 状況: 画面上で何が変わったか、または停滞しているか
        2. 注意: 集中・休憩・迷走・セキュリティ・個人情報露出の観点で気づいたこと
        3. 次の一手: 5分以内に取れる具体的な行動を1つ
        次の一手は通知タイトルに使うため、20〜30字程度の短い行動文にしてください。できれば動詞から始め、今すぐ着手できる内容にしてください。
        推測しすぎず、画面から分かる範囲に限定してください。
        """
    }
}

private struct ChatPayload: Encodable {
    let model: String
    let stream: Bool
    let messages: [ChatMessage]
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
    let images: [String]
}

private struct ChatResponse: Decodable {
    let message: ChatResponseMessage?
    let response: String?
}

private struct ChatResponseMessage: Decodable {
    let content: String
}

enum OllamaError: LocalizedError {
    case badResponse
    case missingContent

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "Ollama APIから成功レスポンスが返りませんでした。"
        case .missingContent:
            return "Ollama APIレスポンスに本文がありませんでした。"
        }
    }
}
