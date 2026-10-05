import Flutter
import UIKit
import Vision
#if canImport(VisionKit)
import VisionKit
#endif

public class FlutterCreditCardScannerPlugin: NSObject, FlutterPlugin {
  private var pendingResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_credit_card_scanner", binaryMessenger: registrar.messenger())
    let instance = FlutterCreditCardScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "scanCard":
      if pendingResult != nil {
        result(FlutterError(code: "ALREADY_ACTIVE", message: "A scan is already in progress", details: nil))
        return
      }
      pendingResult = result
      let args = call.arguments as? [String: Any]
      let scanExpiry = (args?["scanExpiry"] as? Bool) ?? true
      let scanName = (args?["scanCardholderName"] as? Bool) ?? false
      let restrictBrand = args?["restrictBrand"] as? String
      let timeoutMs = args?["timeoutMs"] as? Int
      presentScanner(scanExpiry: scanExpiry, scanName: scanName, restrictBrand: restrictBrand, timeoutMs: timeoutMs)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
    .first?.rootViewController) -> UIViewController? {
    if let nav = base as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = base as? UITabBarController {
      return topViewController(base: tab.selectedViewController)
    }
    if let presented = base?.presentedViewController {
      return topViewController(base: presented)
    }
    return base
  }

  private func presentScanner(scanExpiry: Bool, scanName: Bool, restrictBrand: String?, timeoutMs: Int?) {
    guard let presenter = topViewController() else {
      completeWithError(code: "NO_VIEW", message: "Unable to find top view controller")
      return
    }

    if #available(iOS 16.0, *), isDataScannerSupported() {
      let controller = DataScannerCoordinator(scanExpiry: scanExpiry, scanName: scanName, restrictBrand: restrictBrand) { [weak self] result in
        self?.dismissPresented(animated: true) {
          self?.handleScanResult(result)
        }
      }
      presenter.present(controller, animated: true) {
        controller.startScanning()
      }
      if let timeoutMs = timeoutMs, timeoutMs > 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) { [weak self] in
          guard let self = self, let vc = presenter.presentedViewController as? DataScannerCoordinator else { return }
          vc.finishDueToTimeout()
        }
      }
    } else {
      // Fallback: capture a still image via document camera and OCR it
      let doc = DocumentCameraCoordinator(scanExpiry: scanExpiry, scanName: scanName, restrictBrand: restrictBrand) { [weak self] result in
        self?.dismissPresented(animated: true) {
          self?.handleScanResult(result)
        }
      }
      presenter.present(doc, animated: true, completion: nil)
      if let timeoutMs = timeoutMs, timeoutMs > 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) { [weak self] in
          guard let self = self, let vc = presenter.presentedViewController as? DocumentCameraCoordinator else { return }
          vc.finishDueToTimeout()
        }
      }
    }
  }

  private func dismissPresented(animated: Bool, completion: (() -> Void)? = nil) {
    topViewController()?.dismiss(animated: animated, completion: completion)
  }

  private func handleScanResult(_ result: CardScanOutcome) {
    switch result {
    case .success(let payload):
      completeWithMap(payload)
    case .cancelled:
      completeWithNil()
    case .timeout:
      completeWithError(code: "TIMEOUT", message: "Scan timed out")
    case .failure(let errorMessage):
      completeWithError(code: "SCAN_ERROR", message: errorMessage)
    }
  }

  private func completeWithMap(_ map: [String: Any]) {
    pendingResult?(map)
    pendingResult = nil
  }

  private func completeWithNil() {
    pendingResult?(nil)
    pendingResult = nil
  }

  private func completeWithError(code: String, message: String) {
    pendingResult?(FlutterError(code: code, message: message, details: nil))
    pendingResult = nil
  }

  @available(iOS 16.0, *)
  private func isDataScannerSupported() -> Bool {
    #if canImport(VisionKit)
    return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    #else
    return false
    #endif
  }
}

// MARK: - Shared Parsing Utilities

fileprivate func luhnIsValid(_ number: String) -> Bool {
  let digits = number.compactMap { Int(String($0)) }
  guard digits.count >= 12 else { return false }
  var sum = 0
  for (idx, digit) in digits.reversed().enumerated() {
    if idx % 2 == 1 {
      let doubled = digit * 2
      sum += (doubled > 9) ? (doubled - 9) : doubled
    } else {
      sum += digit
    }
  }
  return sum % 10 == 0
}

fileprivate func detectBrand(_ number: String) -> String? {
  if number.hasPrefix("4") { return "visa" }
  if number.hasPrefix("34") || number.hasPrefix("37") { return "amex" }
  if number.hasPrefix("6011") || number.hasPrefix("65") || (number.hasPrefix("64") && number.count >= 3 && (640...649).contains(Int(number.prefix(3)) ?? 0)) { return "discover" }
  if number.hasPrefix("35") { return "jcb" }
  if number.hasPrefix("62") { return "unionpay" }
  if let firstTwo = Int(number.prefix(2)), (51...55).contains(firstTwo) { return "mastercard" }
  if let firstFour = Int(number.prefix(4)), (2221...2720).contains(firstFour) { return "mastercard" }
  if number.hasPrefix("36") || number.hasPrefix("38") || number.hasPrefix("39") || number.hasPrefix("300") || number.hasPrefix("301") || number.hasPrefix("302") || number.hasPrefix("303") || number.hasPrefix("304") || number.hasPrefix("305") { return "diners" }
  return nil
}

fileprivate func parseExpiry(from text: String) -> (Int, Int)? {
  // Matches MM/YY or MM/YYYY
  let patterns = [
    "(?:0[1-9]|1[0-2])[\\/\\- ]?(?:2[0-9]{3}|[0-9]{2})"
  ]
  for pattern in patterns {
    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
      let range = NSRange(text.startIndex..<text.endIndex, in: text)
      if let match = regex.firstMatch(in: text, options: [], range: range) {
        if let r = Range(match.range, in: text) {
          let raw = String(text[r]).replacingOccurrences(of: " ", with: "")
          let parts = raw.replacingOccurrences(of: "-", with: "/").split(separator: "/")
          if parts.count == 2, let month = Int(parts[0]) {
            var year = String(parts[1])
            if year.count == 2 { year = "20" + year }
            if let y = Int(year) { return (month, y) }
          }
        }
      }
    }
  }
  return nil
}

fileprivate enum CardScanOutcome {
  case success([String: Any])
  case cancelled
  case timeout
  case failure(String)
}

#if canImport(VisionKit)
// MARK: - iOS 16+ Live Scanner (VisionKit DataScanner)
@available(iOS 16.0, *)
fileprivate class DataScannerCoordinator: UIViewController, DataScannerViewControllerDelegate {
  private let scanExpiry: Bool
  private let scanName: Bool
  private let restrictBrand: String?
  private let onResult: (CardScanOutcome) -> Void
  private var scanner: DataScannerViewController?

  init(scanExpiry: Bool, scanName: Bool, restrictBrand: String?, onResult: @escaping (CardScanOutcome) -> Void) {
    self.scanExpiry = scanExpiry
    self.scanName = scanName
    self.restrictBrand = restrictBrand?.lowercased()
    self.onResult = onResult
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
    view.backgroundColor = .black
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func startScanning() {
    let types: [DataScannerViewController.RecognizedDataType]
    if #available(iOS 17.0, *) {
      types = [.text(textContentType: .creditCardNumber)]
    } else {
      types = [.text()]
    }
    let scanner = DataScannerViewController(
      recognizedDataTypes: types,
      qualityLevel: .balanced,
      recognizesMultipleItems: false,
      isHighFrameRateTrackingEnabled: false,
      isPinchToZoomEnabled: true,
      isGuidanceEnabled: true,
      isHighlightingEnabled: false
    )
    scanner.delegate = self
    self.scanner = scanner
    addChild(scanner)
    scanner.view.frame = view.bounds
    view.addSubview(scanner.view)
    scanner.didMove(toParent: self)
    try? scanner.startScanning()

    // Add a close button
    let close = UIButton(type: .system)
    close.setTitle("Cancel", for: .normal)
    close.tintColor = .white
    close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    close.frame = CGRect(x: 16, y: 48, width: 80, height: 44)
    view.addSubview(close)
  }

  @objc private func closeTapped() { onResult(.cancelled) }

  func finishDueToTimeout() { onResult(.timeout) }

  func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
    process(items: addedItems)
  }

  func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
    process(items: updatedItems)
  }

  private func process(items: [RecognizedItem]) {
    for item in items {
      switch item {
      case .text(let text):
        let candidate = text.transcript.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        if candidate.count >= 12, candidate.count <= 19, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: candidate)), luhnIsValid(candidate) {
          if let brand = detectBrand(candidate) {
            if let restrict = restrictBrand, brand != restrict { continue }
            var payload: [String: Any] = ["cardNumber": candidate, "cardBrand": brand]
            if scanExpiry, let (m, y) = parseExpiry(from: text.transcript) {
              payload["expiryMonth"] = m
              payload["expiryYear"] = y
            }
            // Name scanning is unreliable in text streams; omit unless requested
            if scanName {
              // Heuristic: look for two consecutive uppercase words 2-26 chars
              if let name = extractLikelyName(from: text.transcript) { payload["cardholderName"] = name }
            }
            onResult(.success(payload))
            return
          }
        }
      default:
        break
      }
    }
  }

  private func extractLikelyName(from source: String) -> String? {
    let words = source.split(separator: " ").map(String.init)
    let caps = words.filter { $0.count >= 2 && $0.count <= 26 && $0 == $0.uppercased() && $0.rangeOfCharacter(from: .letters) != nil }
    if caps.count >= 2 { return caps.prefix(2).joined(separator: " ") }
    return nil
  }
}
#endif

// MARK: - iOS 13+ Document Camera fallback
fileprivate class DocumentCameraCoordinator: UIViewController, UINavigationControllerDelegate {
  private let scanExpiry: Bool
  private let scanName: Bool
  private let restrictBrand: String?
  private let onResult: (CardScanOutcome) -> Void

  init(scanExpiry: Bool, scanName: Bool, restrictBrand: String?, onResult: @escaping (CardScanOutcome) -> Void) {
    self.scanExpiry = scanExpiry
    self.scanName = scanName
    self.restrictBrand = restrictBrand?.lowercased()
    self.onResult = onResult
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
    view.backgroundColor = .black
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    presentCamera()
  }

  @objc private func closeTapped() { onResult(.cancelled) }

  func finishDueToTimeout() { onResult(.timeout) }

  private func presentCamera() {
    if #available(iOS 13.0, *), let cls = NSClassFromString("VNDocumentCameraViewController") as? UIViewController.Type, let vc = (cls as? (NSObject.Type))?.init() as? UIViewController {
      // We cannot strongly type VNDocumentCameraViewController without importing VisionKit on older iOS, so use UIImagePicker fallback
      // Fallback immediately to picker for simplicity
      presentImagePicker()
    } else {
      presentImagePicker()
    }
  }

  private func presentImagePicker() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      onResult(.failure("Camera not available")); return
    }
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = self
    present(picker, animated: true)
  }

  private func process(image: UIImage) {
    guard let cgImage = image.cgImage else { onResult(.failure("Invalid image")); return }
    let request = VNRecognizeTextRequest { [weak self] req, _ in
      guard let self = self else { return }
      let observations = req.results as? [VNRecognizedTextObservation] ?? []
      let texts: [String] = observations.compactMap { $0.topCandidates(1).first?.string }
      let joined = texts.joined(separator: " ")
      let cleaned = joined.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
      // Try sequences of digits between 12 and 19
      if let number = self.firstValidCardNumber(in: cleaned) {
        if let brand = detectBrand(number) {
          if let restrict = self.restrictBrand, brand != restrict {
            self.onResult(.failure("Card brand does not match restriction")); return
          }
          var payload: [String: Any] = ["cardNumber": number, "cardBrand": brand]
          if self.scanExpiry, let (m, y) = parseExpiry(from: joined) {
            payload["expiryMonth"] = m
            payload["expiryYear"] = y
          }
          if self.scanName, let name = self.extractLikelyName(from: joined) {
            payload["cardholderName"] = name
          }
          self.onResult(.success(payload))
          return
        }
      }
      self.onResult(.failure("No valid card detected"))
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try? handler.perform([request])
  }

  private func firstValidCardNumber(in text: String) -> String? {
    // Find sequences of 12-19 digits and validate via Luhn
    let pattern = "\\d{12,19}"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = regex.matches(in: text, options: [], range: range)
    for m in matches {
      if let r = Range(m.range, in: text) {
        let candidate = String(text[r])
        if luhnIsValid(candidate) { return candidate }
      }
    }
    return nil
  }

  private func extractLikelyName(from source: String) -> String? {
    let words = source.split(separator: " ").map(String.init)
    let caps = words.filter { $0.count >= 2 && $0.count <= 26 && $0 == $0.uppercased() && $0.rangeOfCharacter(from: .letters) != nil }
    if caps.count >= 2 { return caps.prefix(2).joined(separator: " ") }
    return nil
  }
}

extension DocumentCameraCoordinator: UIImagePickerControllerDelegate {
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    onResult(.cancelled)
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true) { [weak self] in
      guard let self = self else { return }
      let image = (info[.originalImage] as? UIImage) ?? (info[.editedImage] as? UIImage)
      if let img = image { self.process(image: img) } else { self.onResult(.failure("No image")) }
    }
  }
}
