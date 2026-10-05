import Flutter
import UIKit
#if canImport(VisionKit)
import VisionKit
#endif

public class FlutterPassportScannerPlugin: NSObject, FlutterPlugin {
  private var pendingResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_passport_scanner", binaryMessenger: registrar.messenger())
    let instance = FlutterPassportScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "scanPassport":
      if pendingResult != nil {
        result(FlutterError(code: "ALREADY_ACTIVE", message: "A scan is already in progress", details: nil))
        return
      }
      pendingResult = result
      let args = call.arguments as? [String: Any]
      let pageLimit = (args?["pageLimit"] as? Int) ?? 1
      presentDocumentCamera(pageLimit: max(1, min(pageLimit, 10)))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
    .first?.rootViewController) -> UIViewController? {
    if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
    if let tab = base as? UITabBarController { return topViewController(base: tab.selectedViewController) }
    if let presented = base?.presentedViewController { return topViewController(base: presented) }
    return base
  }

  private func presentDocumentCamera(pageLimit: Int) {
    DispatchQueue.main.async {
      guard let presenter = self.topViewController() else {
        self.completeWithError(code: "NO_VIEW", message: "Unable to find top view controller")
        return
      }

      #if canImport(VisionKit)
      guard VNDocumentCameraViewController.isSupported else {
        self.completeWithError(code: "UNAVAILABLE", message: "Document camera is not supported on this device")
        return
      }
      let controller = PassportDocumentCameraCoordinator(pageLimit: pageLimit) { [weak self] outcome in
        guard let self = self else { return }
        presenter.dismiss(animated: true) {
          self.handleOutcome(outcome)
        }
      }
      presenter.present(controller, animated: true, completion: nil)
      #else
      self.completeWithError(code: "UNAVAILABLE", message: "VisionKit is not available")
      #endif
    }
  }

  private func handleOutcome(_ outcome: PassportScanOutcome) {
    switch outcome {
    case .success(let payload):
      pendingResult?(payload)
      pendingResult = nil
    case .cancelled:
      pendingResult?(nil)
      pendingResult = nil
    case .failure(let message):
      completeWithError(code: "SCAN_ERROR", message: message)
    }
  }

  private func completeWithError(code: String, message: String) {
    pendingResult?(FlutterError(code: code, message: message, details: nil))
    pendingResult = nil
  }
}

fileprivate enum PassportScanOutcome {
  case success([String: Any])
  case cancelled
  case failure(String)
}

#if canImport(VisionKit)
fileprivate final class PassportDocumentCameraCoordinator: VNDocumentCameraViewController, VNDocumentCameraViewControllerDelegate {
  private let pageLimit: Int
  private let onResult: (PassportScanOutcome) -> Void

  init(pageLimit: Int, onResult: @escaping (PassportScanOutcome) -> Void) {
    self.pageLimit = pageLimit
    self.onResult = onResult
    super.init(nibName: nil, bundle: nil)
    self.delegate = self
    self.modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    onResult(.cancelled)
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    onResult(.failure(error.localizedDescription))
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    let limit = min(scan.pageCount, pageLimit)
    do {
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent("flutter_passport_scanner", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

      var paths: [String] = []
      for i in 0..<limit {
        let image = scan.imageOfPage(at: i)
        guard let data = image.jpegData(compressionQuality: 0.92) else { continue }
        let fileURL = folder.appendingPathComponent("page_\(i)_\(UUID().uuidString).jpg")
        try data.write(to: fileURL, options: [.atomic])
        paths.append(fileURL.path)
      }
      onResult(.success(["imagePaths": paths]))
    } catch {
      onResult(.failure(error.localizedDescription))
    }
  }
}
#endif
