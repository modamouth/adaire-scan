import Flutter
import UIKit
import AVFoundation

public class FlutterBarcodeQrScannerPlugin: NSObject, FlutterPlugin {
  private var pendingResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_barcode_qr_scanner", binaryMessenger: registrar.messenger())
    let instance = FlutterBarcodeQrScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "scan":
      guard pendingResult == nil else {
        result(FlutterError(code: "ALREADY_ACTIVE", message: "A scan is already in progress", details: nil))
        return
      }
      let args = call.arguments as? [String: Any]
      let formats = args?["formats"] as? [String]
      pendingResult = result
      requestCameraAndPresent(formats: formats)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestCameraAndPresent(formats: [String]?) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      presentScanner(formats: formats)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          if granted { self?.presentScanner(formats: formats) }
          else { self?.finishWithCancel() }
        }
      }
    default:
      finishWithCancel()
    }
  }

  private func presentScanner(formats: [String]?) {
    guard let root = topViewController() else { finishWithCancel(); return }
    let vc = ScannerViewController(acceptedTypes: mapFormats(formats)) { [weak self] value, type in
      if let value = value, let type = type {
        self?.pendingResult?(["value": value, "type": type])
      } else {
        self?.pendingResult?(nil)
      }
      self?.pendingResult = nil
    }
    vc.modalPresentationStyle = .fullScreen
    root.present(vc, animated: true)
  }

  private func finishWithCancel() {
    pendingResult?(nil)
    pendingResult = nil
  }

  private func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .flatMap { $0.windows }
    .first { $0.isKeyWindow }?.rootViewController) -> UIViewController? {
      if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
      if let tab = base as? UITabBarController { return topViewController(base: tab.selectedViewController) }
      if let presented = base?.presentedViewController { return topViewController(base: presented) }
      return base
  }

  private func mapFormats(_ keys: [String]?) -> [AVMetadataObject.ObjectType] {
    guard let keys = keys, !keys.isEmpty else { return defaultTypes }
    let mapped = keys.compactMap { keyToType($0) }
    return mapped.isEmpty ? defaultTypes : mapped
  }

  private let defaultTypes: [AVMetadataObject.ObjectType] = [
    .qr, .ean13, .ean8, .code128, .code39, .code93, .upce, .pdf417, .aztec, .dataMatrix, .itf14
  ]

  private func keyToType(_ key: String) -> AVMetadataObject.ObjectType? {
    switch key.lowercased() {
    case "qr": return .qr
    case "ean13": return .ean13
    case "ean8": return .ean8
    case "code128": return .code128
    case "code39": return .code39
    case "code93": return .code93
    case "upce": return .upce
    case "pdf417": return .pdf417
    case "aztec": return .aztec
    case "datamatrix": return .dataMatrix
    case "itf": return .itf14
    default: return nil
    }
  }
}

private final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  private let session = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private let acceptedTypes: [AVMetadataObject.ObjectType]
  private let completion: (_ value: String?, _ type: String?) -> Void
  private var torchOn: Bool = false

  init(acceptedTypes: [AVMetadataObject.ObjectType], completion: @escaping (_ value: String?, _ type: String?) -> Void) {
    self.acceptedTypes = acceptedTypes
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    setupSession()
    addCloseButton()
    addFlashButton()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.bounds
  }

  private func setupSession() {
    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device) else {
      completion(nil, nil)
      return
    }

    session.beginConfiguration()
    if session.canAddInput(input) { session.addInput(input) }

    let output = AVCaptureMetadataOutput()
    if session.canAddOutput(output) { session.addOutput(output) }
    output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    output.metadataObjectTypes = acceptedTypes

    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(layer)
    previewLayer = layer

    session.commitConfiguration()
    session.startRunning()
  }

  private func addCloseButton() {
    let button = UIButton(type: .system)
    button.setTitle("Close", for: .normal)
    button.tintColor = .white
    button.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    button.layer.cornerRadius = 8
    button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(button)
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
    ])
  }

  private func addFlashButton() {
    let button = UIButton(type: .system)
    button.setTitle("Flash", for: .normal)
    button.tintColor = .white
    button.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    button.layer.cornerRadius = 8
    button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    button.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(button)
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
    ])
  }

  @objc private func closeTapped() {
    setTorch(on: false)
    session.stopRunning()
    dismiss(animated: true) { [completion] in completion(nil, nil) }
  }

  @objc private func flashTapped() {
    torchOn.toggle()
    setTorch(on: torchOn)
  }

  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          let value = first.stringValue else { return }
    setTorch(on: false)
    session.stopRunning()
    dismiss(animated: true) { [completion] in
      completion(value, self.typeToKey(first.type))
    }
  }

  private func typeToKey(_ type: AVMetadataObject.ObjectType) -> String {
    switch type {
    case .qr: return "qr"
    case .ean13: return "ean13"
    case .ean8: return "ean8"
    case .code128: return "code128"
    case .code39: return "code39"
    case .code93: return "code93"
    case .upce: return "upce"
    case .pdf417: return "pdf417"
    case .aztec: return "aztec"
    case .dataMatrix: return "datamatrix"
    case .itf14: return "itf"
    default: return "unknown"
    }
  }

  private func setTorch(on: Bool) {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      device.torchMode = on ? .on : .off
      device.unlockForConfiguration()
    } catch {
      // ignore torch failures silently
    }
  }
}
