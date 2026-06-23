import CoreGraphics
import Foundation

final class ScreenshotCapturer {
    let maxEdge: Int

    init(maxEdge: Int) {
        self.maxEdge = maxEdge
    }

    func capture(to destination: URL) throws {
        guard let screenshot = CGWindowListCreateImage(
            .null,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) ?? CGDisplayCreateImage(CGMainDisplayID()) else {
            throw ScreenshotError.captureFailed
        }

        let image = try ImageTools.scaled(screenshot, maxEdge: maxEdge)
        try ImageTools.writePNG(image, to: destination)
    }
}

enum ScreenshotError: LocalizedError {
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .captureFailed:
            return "スクリーンショットを撮れませんでした。画面収録権限を確認してください。"
        }
    }
}
