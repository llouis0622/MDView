import AppKit
import WebKit

final class ResourceHandler: NSObject, WKURLSchemeHandler {
    var root: URL?
    var session = ""
    var cache: [String: Data] = [:]
    var cacheBytes = 0
    var resourceRoot = Bundle.main.resourceURL!
    func setDocument(_ url: URL, session: String) {
        root = url.deletingLastPathComponent(); self.session = session; cache.removeAll(); cacheBytes = 0
    }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        var data: Data?, mime = "application/octet-stream"
        if url.scheme == "mdview", url.host == "bundle" {
            let name = url.lastPathComponent
            let types = ["index.html":"text/html", "viewer.js":"text/javascript", "viewer.css":"text/css"]
            if let type = types[name], url.path == "/" + name {
                data = try? Data(contentsOf: resourceRoot.appendingPathComponent(name)); mime = type
            }
        } else if url.scheme == "mdimage", url.host == session, let root,
                  let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath,
                  let path = String(encoded.dropFirst()).removingPercentEncoding?.removingPercentEncoding {
            // Markdown-it percent-encodes filenames; the renderer then encodes the whole source.
            mime = "image/png"
            if let cached = cache[path] { data = cached }
            else if cacheBytes < 32 * 1024 * 1024, cache.count < 100, let image = LocalImage.png(path, under: root) {
                data = image; cache[path] = image; cacheBytes += image.count
            }
        }
        guard let data else { task.didFailWithError(URLError(.resourceUnavailable)); return }
        task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: mime.hasPrefix("text/") ? "utf-8" : nil))
        task.didReceive(data); task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

final class ReaderWebView: WKWebView {
    var onDrop: (([URL]) -> Bool)?
    static func fileURLs(_ pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Self.fileURLs(sender.draggingPasteboard).count == 1 ? .copy : []
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { Self.fileURLs(sender.draggingPasteboard).count == 1 }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { onDrop?(Self.fileURLs(sender.draggingPasteboard)) ?? false }
}
