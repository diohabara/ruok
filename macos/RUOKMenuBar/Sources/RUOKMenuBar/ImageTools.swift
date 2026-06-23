import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageToolError: Error {
    case imageDestinationFailed(URL)
    case imageWriteFailed(URL)
    case resizeFailed
}

enum ImageTools {
    static func loadImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageToolError.imageDestinationFailed(url)
        }
        CGImageDestinationAddImage(destination, image, nil)
        if !CGImageDestinationFinalize(destination) {
            throw ImageToolError.imageWriteFailed(url)
        }
    }

    static func scaled(_ image: CGImage, maxEdge: Int) throws -> CGImage {
        let longestEdge = max(image.width, image.height)
        guard longestEdge > maxEdge else {
            return image
        }

        let scale = Double(maxEdge) / Double(longestEdge)
        let width = max(1, Int(Double(image.width) * scale))
        let height = max(1, Int(Double(image.height) * scale))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageToolError.resizeFailed
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let resized = context.makeImage() else {
            throw ImageToolError.resizeFailed
        }
        return resized
    }

    static func compressImageFile(_ url: URL, maxEdge: Int) throws -> Bool {
        guard let image = loadImage(from: url) else {
            return false
        }
        guard max(image.width, image.height) > maxEdge else {
            return false
        }
        let resized = try scaled(image, maxEdge: maxEdge)
        try writePNG(resized, to: url)
        return true
    }
}
