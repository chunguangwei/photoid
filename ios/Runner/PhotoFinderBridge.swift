import Flutter
import UIKit
import UniformTypeIdentifiers
import Vision
import ImageIO
import CryptoKit

/// Owns only explicit picker grants and per-session private caches.
final class PhotoFinderBridge: NSObject, UIDocumentPickerDelegate {
  private struct Entry { let url: URL; let name: String; let relative: String }
  private final class Session {
    let id = UUID().uuidString
    let cache: URL
    var grants: [URL] = []
    var entries: [String: Entry] = [:]
    var interrupted = false
    var cacheBytes = 0
    init(cacheRoot: URL) throws {
      cache = cacheRoot.appendingPathComponent(id, isDirectory: true)
      try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    }
  }
  private let queue = DispatchQueue(label: "photoid.finder", qos: .userInitiated)
  private let cacheRoot: URL
  private var sessions: [String: Session] = [:]
  private var pending: FlutterResult?
  private var recursive = false
  private var directoryPick = false
  private let requestLock = NSLock()
  private var activeRequest: VNRequest?
  private var channel: FlutterMethodChannel!

  init(registrar: FlutterPluginRegistrar) {
    cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("photoid_finder", isDirectory: true)
    super.init()
    try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    if let old = try? FileManager.default.contentsOfDirectory(at: cacheRoot, includingPropertiesForKeys: [.contentModificationDateKey]) {
      for url in old {
        if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           Date().timeIntervalSince(date) > 86400 { try? FileManager.default.removeItem(at: url) }
      }
    }
    channel = FlutterMethodChannel(name: "photoid/photo_finder", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
  }
  private func fail(_ code: String, _ result: @escaping FlutterResult) {
    DispatchQueue.main.async { result(FlutterError(code: code, message: code, details: nil)) }
  }
  private func reply(_ value: Any?, _ result: @escaping FlutterResult) {
    DispatchQueue.main.async { result(value) }
  }
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "chooseDirectory" || call.method == "chooseFiles" {
      guard pending == nil else { fail("busy", result); return }
      pending = result; recursive = args["recursive"] as? Bool ?? false
      directoryPick = call.method == "chooseDirectory"
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: directoryPick ? [.folder] : [.image], asCopy: false)
      picker.allowsMultipleSelection = !directoryPick; picker.delegate = self
      var vc = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.rootViewController }.first
      while let presented = vc?.presentedViewController { vc = presented }
      guard let presenter = vc else { pending = nil; fail("access", result); return }
      presenter.present(picker, animated: true); return
    }
    if call.method == "interrupt" {
      requestLock.lock(); activeRequest?.cancel(); requestLock.unlock()
      queue.async { if let id = args["session"] as? String { self.sessions[id]?.interrupted = true }; self.reply(nil, result) }
      return
    }
    queue.async {
      do {
        if call.method == "openDemo" {
          let paths = args["paths"] as? [String] ?? []
          guard !paths.isEmpty, paths.count <= 500, paths.allSatisfy({ URL(fileURLWithPath: $0).standardizedFileURL.path.hasPrefix(NSHomeDirectory() + "/") }) else { throw FinderError.access }
          let listing = try self.makeSession(urls: paths.map { URL(fileURLWithPath: $0) }, directory: false, recursive: false)
          self.reply(listing, result); return
        }
        guard let id = args["session"] as? String, let session = self.sessions[id] else {
          if call.method == "close" { self.reply(nil, result) } else { self.fail("closed", result) }; return
        }
        if call.method == "close" { self.close(session); self.reply(nil, result); return }
        guard let key = args["id"] as? String, let entry = session.entries[key] else { throw FinderError.access }
        if call.method == "analyze" {
          session.interrupted = false
          var value: [String: Any] = ["id": key, "name": entry.name, "relativePath": entry.relative]
          do { value.merge(try self.analyze(entry, key, session)) { _, new in new } }
          catch let error as FinderError { value["skip"] = error.rawValue }
          catch { value["skip"] = "unreadable" }
          self.reply(value, result)
        } else if call.method == "materialize" {
          let data = try self.readLocal(entry.url)
          guard args["fingerprint"] as? String == self.hash(data) else { throw FinderError.changed }
          let ext = entry.url.pathExtension.lowercased()
          let output = session.cache.appendingPathComponent("selected_" + key + "." + ((ext == "heic" || ext == "heif") ? "jpg" : ext))
          if ext == "heic" || ext == "heif" {
            let info = try self.imageInfo(data)
            let image = try self.thumbnail(data, max: max(info.0, info.1))
            try self.jpeg(image, to: output)
          } else { try data.write(to: output, options: .atomic) }
          self.reply(["path": output.path], result)
        } else { self.reply(FlutterMethodNotImplemented, result) }
      } catch let error as FinderError { self.fail(error.rawValue, result) }
      catch { self.fail("access", result) }
    }
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { let result = pending; pending = nil; result?(nil) }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }; pending = nil
    let directory = directoryPick, descend = recursive
    queue.async {
      do { self.reply(try self.makeSession(urls: urls, directory: directory, recursive: descend), result) }
      catch { self.fail("access", result) }
    }
  }
  private func makeSession(urls: [URL], directory: Bool, recursive: Bool) throws -> [String: Any] {
    let s = try Session(cacheRoot: cacheRoot)
    do {
      for url in urls {
        if url.startAccessingSecurityScopedResource() { s.grants.append(url) }
        else if !url.standardizedFileURL.path.hasPrefix(NSHomeDirectory() + "/") { throw FinderError.access }
      }
      var visited = 0, limited = false
      func append(_ url: URL, relative: String) {
        let ext = url.pathExtension.lowercased()
        guard ["jpg","jpeg","png","heic","heif","webp","gif","bmp","tiff"].contains(ext) else { return }
        let id = UUID().uuidString
        s.entries[id] = Entry(url: url, name: url.lastPathComponent, relative: relative)
      }
      if directory, let root = urls.first {
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: root, options: [], error: &coordinationError) { coordinated in
          let keys: [URLResourceKey] = [.isDirectoryKey,.isSymbolicLinkKey,.isPackageKey]
          let options: FileManager.DirectoryEnumerationOptions = recursive ? [.skipsHiddenFiles,.skipsPackageDescendants] : [.skipsHiddenFiles,.skipsPackageDescendants,.skipsSubdirectoryDescendants]
          if let enumerator = FileManager.default.enumerator(at: coordinated, includingPropertiesForKeys: keys, options: options, errorHandler: { _, _ in limited = true; return true }) {
            for case let url as URL in enumerator {
              if visited >= 2000 || s.entries.count >= 500 { limited = true; break }
              visited += 1
              let values = try? url.resourceValues(forKeys: Set(keys))
              if enumerator.level > 5 || values?.isSymbolicLink == true || values?.isPackage == true { enumerator.skipDescendants(); continue }
              if values?.isDirectory == true { continue }
              let relative = String(url.path.dropFirst(coordinated.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
              append(url, relative: relative)
            }
          } else { limited = true }
        }
        if let error = coordinationError { throw error }
      } else {
        for url in urls.prefix(500) { visited += 1; append(url, relative: url.lastPathComponent) }
        limited = urls.count > 500
      }
      sessions[s.id] = s
      return ["session": s.id, "visited": visited, "truncated": limited, "entries": s.entries.map { ["id": $0.key, "name": $0.value.name, "relativePath": $0.value.relative] }.sorted { ($0["relativePath"] ?? "") < ($1["relativePath"] ?? "") }]
    } catch { close(s); throw error }
  }
  private func close(_ s: Session) { sessions.removeValue(forKey: s.id); s.grants.forEach { $0.stopAccessingSecurityScopedResource() }; try? FileManager.default.removeItem(at: s.cache) }
  private func readLocal(_ url: URL) throws -> Data {
    let ext = url.pathExtension.lowercased()
    guard ["jpg","jpeg","png","heic","heif"].contains(ext) else { throw FinderError.unsupported }
    let v = try url.resourceValues(forKeys: [.fileSizeKey,.isSymbolicLinkKey,.isUbiquitousItemKey,.ubiquitousItemDownloadingStatusKey])
    if v.isSymbolicLink == true { throw FinderError.access }
    if v.isUbiquitousItem == true {
      guard v.ubiquitousItemDownloadingStatus == .current || v.ubiquitousItemDownloadingStatus == .downloaded else { throw FinderError.remote }
    } else {
      let path = url.standardizedFileURL.path
      guard path.hasPrefix(NSHomeDirectory() + "/") || path.contains("/Containers/Data/Application/") else { throw FinderError.remote }
    }
    guard let length = v.fileSize, length <= 30 * 1024 * 1024 else { throw FinderError.oversized }
    var error: NSError?, value: Result<Data, Error>?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { file in
      value = Result { let data = try Data(contentsOf: file, options: .mappedIfSafe); guard data.count <= 30*1024*1024 else { throw FinderError.oversized }; _ = try self.imageInfo(data); return data }
    }
    if let error = error { throw error }; guard let value = value else { throw FinderError.access }; return try value.get()
  }
  private func imageInfo(_ data: Data) throws -> (Int, Int) {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil), let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0 else { throw FinderError.unreadable }
    guard w <= 24000000 / h else { throw FinderError.oversized }
    let orientation = p[kCGImagePropertyOrientation] as? Int ?? 1
    return orientation >= 5 ? (h,w) : (w,h)
  }
  private func thumbnail(_ data: Data, max dimension: Int) throws -> CGImage {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:dimension] as CFDictionary) else { throw FinderError.unreadable }; return image
  }
  private func jpeg(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw FinderError.access }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality:0.9] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw FinderError.access }
  }
  private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format:"%02x",$0) }.joined() }
  private func analyze(_ entry: Entry, _ id: String, _ s: Session) throws -> [String:Any] {
    let data = try readLocal(entry.url), size = try imageInfo(data), image = try thumbnail(data, max: 1280)
    let request = VNDetectFaceRectanglesRequest()
    requestLock.lock(); activeRequest = request; requestLock.unlock()
    defer { requestLock.lock(); activeRequest = nil; requestLock.unlock() }
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    if s.interrupted { throw FinderError.cancelled }
    let thumb = s.cache.appendingPathComponent(id + ".jpg"); try jpeg(image, to: thumb)
    let bytes = (try? thumb.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    guard s.cacheBytes + bytes <= 100 * 1024 * 1024 else { try? FileManager.default.removeItem(at: thumb); throw FinderError.cacheLimit }
    s.cacheBytes += bytes
    let faces: [[String:Any]] = (request.results ?? []).map { face in
      let b = face.boundingBox
      var item: [String:Any] = ["x":b.minX,"y":1-b.maxY,"w":b.width,"h":b.height]
      if let yaw = face.yaw { item["yaw"] = yaw.doubleValue * 180 / .pi }
      if let roll = face.roll { item["roll"] = roll.doubleValue * 180 / .pi }
      return item
    }
    return ["width":size.0,"height":size.1,"faces":faces,"thumbnailPath":thumb.path,"fingerprint":hash(data)]
  }
  private enum FinderError: String, Error { case access, remote, oversized, unsupported, unreadable, changed, cancelled, cacheLimit }
}
