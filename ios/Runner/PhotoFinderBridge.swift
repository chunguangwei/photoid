import Flutter
import UIKit
import PhotosUI
import Photos
import UniformTypeIdentifiers
import Vision
import ImageIO
import CryptoKit

/// Owns only explicit picker grants and per-session private caches.
final class PhotoFinderBridge: NSObject, UIDocumentPickerDelegate, PHPickerViewControllerDelegate {
  private struct Entry {
    let url: URL?; let name: String; let relative: String
    let provider: NSItemProvider?; let type: String?; let direct: Bool; let asset: PHAsset?
    init(url: URL, name: String, relative: String, direct: Bool = false) { self.url=url; self.name=name; self.relative=relative; self.direct=direct; provider=nil; type=nil; asset=nil }
    init(provider: NSItemProvider, type: String, name: String) { self.provider=provider; self.type=type; self.name=name; relative=name; url=nil; direct=true; asset=nil }
    init(asset: PHAsset, name: String) { self.asset=asset; self.name=name; relative=name; url=nil; provider=nil; type=nil; direct=true }
  }
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
  private var activeSession: String?
  private var cancelProvider: (() -> Void)?
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
    if call.method == "choosePhotos" {
      guard pending == nil else { fail("busy", result); return }
      pending=result
      guard let vc=presenter() else { pending=nil; fail("access",result); return }
      let zh=(args["languageCode"] as? String ?? Locale.preferredLanguages.first ?? "en").hasPrefix("zh")
      let picker=PhotoSwipePickerController(zh:zh, complete: { [weak self] assets in
        guard let self=self, let result=self.pending else { return }; self.pending=nil
        guard let assets=assets, !assets.isEmpty else { result(nil); return }
        self.queue.async { do { self.reply(try self.makeAssetSession(assets),result) } catch { self.fail("access",result) } }
      }, useSystem: { [weak self] in self?.presentSystemPhotos() })
      let nav=UINavigationController(rootViewController:picker)
      nav.modalPresentationStyle = .fullScreen; nav.isModalInPresentation=true
      vc.present(nav,animated:true); return
    }
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
      requestLock.lock()
      let matches = activeSession == (args["session"] as? String)
      let cancel = matches ? cancelProvider : nil
      if matches { activeRequest?.cancel() }
      requestLock.unlock(); cancel?()
      queue.async { if let id = args["session"] as? String { self.sessions[id]?.interrupted = true }; self.reply(nil, result) }
      return
    }
    if call.method == "close" {
      requestLock.lock(); let cancel = activeSession == (args["session"] as? String) ? cancelProvider : nil; requestLock.unlock(); cancel?()
    }
    queue.async {
      do {
        if call.method == "openDemo" {
          let paths = args["paths"] as? [String] ?? []
          guard !paths.isEmpty, paths.count <= 500, paths.allSatisfy({ URL(fileURLWithPath: $0).standardizedFileURL.path.hasPrefix(NSHomeDirectory() + "/") }) else { throw FinderError.access }
          if args["asPhotoProviders"] as? Bool == true {
            let providers=paths.map { path -> NSItemProvider in
              let url=URL(fileURLWithPath:path), provider=NSItemProvider()
              provider.suggestedName=url.lastPathComponent
              let type=UTType(filenameExtension:url.pathExtension)?.identifier ?? UTType.jpeg.identifier
              provider.registerFileRepresentation(forTypeIdentifier:type,fileOptions:[],visibility:.all) { completion in completion(url,false,nil);return Progress(totalUnitCount:1) }
              return provider
            }
            self.reply(try self.makePhotoSession(providers),result);return
          }
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
          let data = try self.readEntry(entry, session.id)
          guard args["fingerprint"] as? String == self.hash(data) else { throw FinderError.changed }
          let format = CGImageSourceCreateWithData(data as CFData,nil).flatMap { CGImageSourceGetType($0) } as String?
          let ext = format == UTType.png.identifier ? "png" : (format == UTType.heic.identifier || format == "public.heif" ? "heic" : "jpg")
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
  private func presenter() -> UIViewController? {
    var vc=UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first(where:{$0.isKeyWindow})?.rootViewController }.first
    while let next=vc?.presentedViewController { vc=next };return vc
  }
  private func presentSystemPhotos() {
    guard let result=pending else { return }
    guard let vc=presenter() else { pending=nil;fail("access",result);return }
    var config=PHPickerConfiguration();config.filter = .images;config.selectionLimit=500
    config.selection = .ordered;config.preferredAssetRepresentationMode = .current
    let picker=PHPickerViewController(configuration:config);picker.delegate=self
    vc.present(picker,animated:true)
  }
  private func makeAssetSession(_ assets: [PHAsset]) throws -> [String:Any] {
    let s=try Session(cacheRoot:cacheRoot)
    for (index,asset) in assets.prefix(500).enumerated() {
      let resources=PHAssetResource.assetResources(for:asset)
      let resource=resources.first(where:{$0.type == .fullSizePhoto}) ?? resources.first(where:{$0.type == .photo})
      let name=resource?.originalFilename ?? "Photo_\(index+1).jpg"
      s.entries[UUID().uuidString]=Entry(asset:asset,name:name)
    }
    sessions[s.id]=s
    return ["session":s.id,"visited":assets.count,"truncated":assets.count>500,"entries":s.entries.map {["id":$0.key,"name":$0.value.name,"relativePath":$0.value.relative]}.sorted {($0["name"] ?? "") < ($1["name"] ?? "")}]
  }
  /// Bounded streaming avoids allocating an entire cloud original before the size check.
  private func readPhotoAsset(_ asset: PHAsset, _ sessionID: String) throws -> Data {
    guard asset.pixelHeight > 0, asset.pixelWidth <= 24000000 / asset.pixelHeight else { throw FinderError.oversized }
    let resources=PHAssetResource.assetResources(for:asset)
    guard let resource=resources.first(where:{$0.type == .fullSizePhoto}) ?? resources.first(where:{$0.type == .photo}) else { throw FinderError.unreadable }
    guard [UTType.jpeg.identifier,UTType.png.identifier,UTType.heic.identifier,"public.heif"].contains(resource.uniformTypeIdentifier) else { throw FinderError.unsupported }
    let manager=PHAssetResourceManager.default(), options=PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed=true // Only photos explicitly confirmed by the user.
    let gate=DispatchSemaphore(value:0), lock=NSLock()
    var bytes=Data(), outcome: Result<Data,Error>?, requestID: PHAssetResourceDataRequestID?
    func complete(_ result: Result<Data,Error>) {
      lock.lock();defer{lock.unlock()}
      if outcome == nil { outcome=result;gate.signal() }
    }
    let id=manager.requestData(for:resource,options:options,dataReceivedHandler: { chunk in
      lock.lock()
      if outcome != nil { lock.unlock();return }
      if chunk.count > 30*1024*1024-bytes.count {
        outcome = .failure(FinderError.oversized);bytes.removeAll();let cancel=requestID;gate.signal();lock.unlock()
        if let cancel=cancel { manager.cancelDataRequest(cancel) };return
      }
      bytes.append(chunk);lock.unlock()
    },completionHandler: { error in
      lock.lock();let result:Result<Data,Error> = error.map { .failure($0) } ?? .success(bytes);lock.unlock()
      complete(result)
    })
    lock.lock();requestID=id;let alreadyFinished=outcome != nil;lock.unlock()
    if alreadyFinished { manager.cancelDataRequest(id) }
    requestLock.lock();activeSession=sessionID;cancelProvider={ complete(.failure(FinderError.cancelled));manager.cancelDataRequest(id) };requestLock.unlock()
    defer { requestLock.lock();cancelProvider=nil;requestLock.unlock() }
    if gate.wait(timeout:.now()+45) == .timedOut { complete(.failure(FinderError.access));manager.cancelDataRequest(id);throw FinderError.access }
    lock.lock();let result=outcome;lock.unlock()
    let data=try result!.get();_ = try imageInfo(data);return data
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    let result=pending;pending=nil;picker.dismiss(animated:true)
    guard let result=result else { return }
    guard !results.isEmpty else { result(nil);return }
    queue.async { do { self.reply(try self.makePhotoSession(results.prefix(500).map { $0.itemProvider }),result) } catch { self.fail("access",result) } }
  }
  private func makePhotoSession(_ providers: [NSItemProvider]) throws -> [String:Any] {
    let s=try Session(cacheRoot:cacheRoot)
    for (index,provider) in providers.prefix(500).enumerated() {
      let type=provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to:.image) == true } ?? UTType.image.identifier
      var name=provider.suggestedName ?? "Photo_\(index+1)"
      if URL(fileURLWithPath:name).pathExtension.isEmpty { name += "." + (UTType(type)?.preferredFilenameExtension ?? "jpg") }
      s.entries[UUID().uuidString]=Entry(provider:provider,type:type,name:name)
    }
    sessions[s.id]=s
    return ["session":s.id,"visited":providers.count,"truncated":providers.count>500,"entries":s.entries.map {["id":$0.key,"name":$0.value.name,"relativePath":$0.value.relative]}.sorted {($0["name"] ?? "") < ($1["name"] ?? "")}]
  }
  /// Retain provider handles, not hundreds of originals. Read one scoped representation at a time.
  private func readEntry(_ entry: Entry, _ sessionID: String) throws -> Data {
    if let asset=entry.asset { return try readPhotoAsset(asset,sessionID) }
    guard let provider=entry.provider, let type=entry.type else { return try readLocal(entry.url!, direct:entry.direct) }
    let gate=DispatchSemaphore(value:0), lock=NSLock()
    var outcome: Result<Data,Error>?
    func complete(_ value: Result<Data,Error>) { lock.lock();defer{lock.unlock()};if outcome == nil { outcome=value;gate.signal() } }
    let progress=provider.loadFileRepresentation(forTypeIdentifier:type) { url,error in
      lock.lock();let finished=outcome != nil;lock.unlock();if finished { return }
      guard let url=url else { complete(.failure(error ?? FinderError.unreadable));return }
      complete(Result { try self.readLocal(url,direct:true,providerRepresentation:true) })
    }
    requestLock.lock(); activeSession=sessionID;cancelProvider={ complete(.failure(FinderError.cancelled));progress.cancel() };requestLock.unlock()
    defer { requestLock.lock();cancelProvider=nil;requestLock.unlock() }
    if gate.wait(timeout:.now()+45) == .timedOut { complete(.failure(FinderError.access));progress.cancel();throw FinderError.access }
    lock.lock();let value=outcome;lock.unlock()
    return try value!.get()
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
        s.entries[id] = Entry(url: url, name: url.lastPathComponent, relative: relative, direct: !directory)
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
  private func readLocal(_ url: URL, direct: Bool = false, providerRepresentation: Bool = false) throws -> Data {
    guard url.isFileURL else { throw FinderError.access }
    let ext = url.pathExtension.lowercased()
    guard providerRepresentation || ["jpg","jpeg","png","heic","heif"].contains(ext) else { throw FinderError.unsupported }
    let v = try url.resourceValues(forKeys: [.fileSizeKey,.isSymbolicLinkKey,.isUbiquitousItemKey,.ubiquitousItemDownloadingStatusKey])
    if v.isSymbolicLink == true { throw FinderError.access }
    if !direct && v.isUbiquitousItem == true {
      guard v.ubiquitousItemDownloadingStatus == .current || v.ubiquitousItemDownloadingStatus == .downloaded else { throw FinderError.remote }
    } else if !direct {
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
    let format = CGImageSourceGetType(source) as String?
    guard [UTType.jpeg.identifier,UTType.png.identifier,UTType.heic.identifier,"public.heif"].contains(format ?? "") else { throw FinderError.unsupported }
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
    let data = try readEntry(entry, s.id), size = try imageInfo(data), image = try thumbnail(data, max: 1280)
    let request = VNDetectFaceRectanglesRequest()
    requestLock.lock(); activeSession=s.id; activeRequest = request; requestLock.unlock()
    defer { requestLock.lock(); activeRequest = nil; requestLock.unlock() }
    NSLog("PhotoFinder perform-start name=%@", entry.name)
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    NSLog("PhotoFinder perform-done name=%@", entry.name)
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
