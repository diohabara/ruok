import CoreGraphics
import Foundation
import ImageIO

enum ImageDiffError: Error {
    case imageLoadFailed(URL)
    case bitmapContextFailed
}

struct ImageDelta {
    let changedPercent: Double
    let rms: Double
    let summary: String

    static let initial = ImageDelta(
        changedPercent: 100,
        rms: 0,
        summary: "初回チェックです。"
    )
}

enum ImageDiffer {
    static func compare(previousURL: URL?, currentURL: URL) throws -> ImageDelta {
        guard let previousURL else {
            return .initial
        }
        guard let previous = ImageTools.loadImage(from: previousURL) else {
            return .initial
        }
        guard let current = ImageTools.loadImage(from: currentURL) else {
            throw ImageDiffError.imageLoadFailed(currentURL)
        }

        let previousPixels = try sample(previous, width: 128, height: 128)
        let currentPixels = try sample(current, width: 128, height: 128)
        var changedPixels = 0
        var squaredDifference = 0.0
        let pixelCount = previousPixels.count / 4

        for pixel in 0..<pixelCount {
            let index = pixel * 4
            let red = Double(Int(currentPixels[index]) - Int(previousPixels[index]))
            let green = Double(Int(currentPixels[index + 1]) - Int(previousPixels[index + 1]))
            let blue = Double(Int(currentPixels[index + 2]) - Int(previousPixels[index + 2]))
            let averageDifference = (abs(red) + abs(green) + abs(blue)) / 3.0
            if averageDifference > 18 {
                changedPixels += 1
            }
            squaredDifference += red * red + green * green + blue * blue
        }

        let changedPercent = Double(changedPixels) / Double(pixelCount) * 100
        let rms = sqrt(squaredDifference / Double(pixelCount * 3))
        return ImageDelta(
            changedPercent: changedPercent,
            rms: rms,
            summary: summary(changedPercent: changedPercent, rms: rms)
        )
    }

    private static func sample(_ image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw ImageDiffError.bitmapContextFailed
            }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw ImageDiffError.bitmapContextFailed
            }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    private static func summary(changedPercent: Double, rms: Double) -> String {
        if changedPercent < 1 || rms < 4 {
            return "ほとんど変化していません。"
        }
        if changedPercent < 8 {
            return "小さな変化があります。"
        }
        if changedPercent < 35 {
            return "画面に変化があります。"
        }
        return "画面が大きく変化しました。"
    }
}
