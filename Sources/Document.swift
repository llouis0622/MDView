import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ViewerDocument {
    static let maxBytes = 8 * 1024 * 1024
    static let richBytes = 1024 * 1024
    let url: URL
    let text: String
    let bytes: Int
    var plain: Bool { bytes > Self.richBytes }
    static func read(_ url: URL) throws -> ViewerDocument {
        guard url.isFileURL, ["md", "markdown", "mdown", "mkd", "txt"].contains(url.pathExtension.lowercased()) else {
            throw ViewerError.message(".md, .markdown, .mdown, .mkd 또는 .txt 파일을 선택해 주세요.")
        }
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard info.isRegularFile == true else { throw ViewerError.message("일반 문서 파일만 열 수 있습니다.") }
        guard (info.fileSize ?? Int.max) <= maxBytes else { throw ViewerError.message("8 MB를 넘는 문서입니다. 더 작은 파일로 나누어 주세요.") }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maxBytes + 1) ?? Data()
        guard data.count <= maxBytes else { throw ViewerError.message("문서 크기는 최대 8 MB까지 지원합니다.") }
        let text: String?
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16)
        } else {
            text = String(data: data, encoding: .utf8)
        }
        guard let decoded = text, !decoded.contains("\0") else {
            throw ViewerError.message("텍스트를 읽을 수 없습니다. UTF-8 또는 BOM이 있는 UTF-16 문서가 필요합니다.")
        }
        return ViewerDocument(url: url, text: decoded.hasPrefix("\u{FEFF}") ? String(decoded.dropFirst()) : decoded, bytes: data.count)
    }
}

enum ViewerError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}

enum LocalImage {
    static func resolve(_ path: String, under root: URL) -> URL? {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("\\"), !path.contains(":"), !path.contains("\0"), !path.contains("\\") else { return nil }
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        let target = base.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        guard target.path.hasPrefix(base.path + "/"), ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "tif", "bmp"].contains(target.pathExtension.lowercased()) else { return nil }
        return target
    }
    static func png(_ path: String, under root: URL) -> Data? {
        guard let url = resolve(path, under: root),
              let info = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              info.isRegularFile == true, let size = info.fileSize, size <= 12 * 1024 * 1024,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 12 * 1024 * 1024 + 1), data.count <= 12 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 16000, height <= 16000, width * height <= 40_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2400] as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
