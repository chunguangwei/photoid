import Flutter
import UIKit
import Vision
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var transparencyObserver: NSObjectProtocol?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let ocrRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhotoIDRequirementsOCR") {
      let ocr = FlutterMethodChannel(name: "photoid/requirements_ocr", binaryMessenger: ocrRegistrar.messenger())
      ocr.setMethodCallHandler { call, result in
        guard call.method == "recognize", let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else { result(FlutterMethodNotImplemented); return }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let url = URL(fileURLWithPath: path)
            guard let image = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
                  let width = props[kCGImagePropertyPixelWidth] as? Int,
                  let height = props[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width * height <= 24_000_000 else {
              throw NSError(domain: "PhotoID", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unreadable or oversized image"])
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let supported = try request.supportedRecognitionLanguages()
            let languages = ["zh-Hans", "en-US"].filter { supported.contains($0) }
            guard !languages.isEmpty else { throw NSError(domain: "PhotoID", code: 2) }
            request.recognitionLanguages = languages
            let handler = VNImageRequestHandler(url: url, options: [:])
            try handler.perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            DispatchQueue.main.async { result(text) }
          } catch {
            DispatchQueue.main.async { result(FlutterError(code: "recognition_failed", message: "Text recognition unavailable or failed", details: nil)) }
          }
        }
      }
    }
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhotoIDAccessibility") else {
      return
    }
    let channel = FlutterMethodChannel(name: "photoid/accessibility", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "getReduceTransparency" {
        result(UIAccessibility.isReduceTransparencyEnabled)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    if let observer = transparencyObserver { NotificationCenter.default.removeObserver(observer) }
    transparencyObserver = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil, queue: .main
    ) { _ in
      channel.invokeMethod("reduceTransparencyChanged", arguments: UIAccessibility.isReduceTransparencyEnabled)
    }
  }
}
