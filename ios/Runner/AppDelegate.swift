import Flutter
import AVFoundation
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private var pendingPhotoResult: FlutterResult?
  private var pendingScanner: BarcodeScannerViewController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "controller_app/native",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getAndroidId":
          result(UIDevice.current.identifierForVendor?.uuidString ?? "")
        case "getAesPasswordSecret":
          result("")
        case "getAesKeySecret":
          result("SW50M3JyNHAxZDFzMW0wQ2w0UzMzbmNyMXBjMTBuUHQyMDIy")
        case "getAesSaltSecret":
          result("MW5UM3JyNHAxZDFTMU0wXzIwMjI=")
        case "takePackagePhoto":
          self?.takePackagePhoto(result: result)
        case "scanQrCode":
          self?.scanQrCode(result: result)
        case "compressImageBase64ToJpeg":
          self?.compressImageBase64ToJpeg(call: call, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func takePackagePhoto(result: @escaping FlutterResult) {
    guard pendingPhotoResult == nil else {
      result(FlutterError(code: "CAMERA_BUSY", message: "Ya hay una captura en proceso.", details: nil))
      return
    }
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      result("")
      return
    }
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = self
    pendingPhotoResult = result
    window?.rootViewController?.present(picker, animated: true)
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
  ) {
    let result = pendingPhotoResult
    pendingPhotoResult = nil
    picker.dismiss(animated: true)
    guard let image = info[.originalImage] as? UIImage,
          let data = compressedJpegData(
            from: image,
            maxDimension: CGFloat(photoMaxDimension),
            quality: CGFloat(photoJpegQuality) / 100,
            maxBase64Length: photoMaxBase64Length
          ) else {
      result?("")
      return
    }
    result?(data.base64EncodedString())
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    let result = pendingPhotoResult
    pendingPhotoResult = nil
    picker.dismiss(animated: true)
    result?("")
  }

  private func scanQrCode(result: @escaping FlutterResult) {
    guard pendingPhotoResult == nil, pendingScanner == nil else {
      result(FlutterError(code: "CAMERA_BUSY", message: "Ya hay una captura en proceso.", details: nil))
      return
    }
    let scanner = BarcodeScannerViewController { [weak self] value in
      self?.pendingScanner = nil
      self?.window?.rootViewController?.dismiss(animated: true)
      result(value)
    }
    pendingScanner = scanner
    window?.rootViewController?.present(scanner, animated: true)
  }

  private func compressImageBase64ToJpeg(call: FlutterMethodCall, result: FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let imageBase64 = arguments["imageBase64"] as? String,
          !imageBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result("")
      return
    }

    let maxDimension = arguments["maxDimension"] as? Int ?? photoMaxDimension
    let quality = arguments["quality"] as? Int ?? photoJpegQuality
    let maxBase64Length = arguments["maxBase64Length"] as? Int ?? photoMaxBase64Length
    let cleanBase64 = cleanBase64Value(imageBase64)
    guard let inputData = Data(base64Encoded: cleanBase64),
          let image = UIImage(data: inputData),
          let outputData = compressedJpegData(
            from: image,
            maxDimension: CGFloat(max(1, maxDimension)),
            quality: CGFloat(min(max(quality, minJpegQuality), maxJpegQuality)) / 100,
            maxBase64Length: max(1, maxBase64Length)
          ) else {
      result("")
      return
    }
    result(outputData.base64EncodedString())
  }

  private func compressedJpegData(
    from image: UIImage,
    maxDimension: CGFloat,
    quality: CGFloat,
    maxBase64Length: Int
  ) -> Data? {
    var currentMaxDimension = max(CGFloat(minImageDimension), maxDimension)
    let initialQuality = min(max(quality, CGFloat(minJpegQuality) / 100), 1)
    var currentQuality = initialQuality
    var bestData: Data?

    while true {
      guard let data = renderJpegData(
        from: image,
        maxDimension: currentMaxDimension,
        quality: currentQuality
      ) else {
        return bestData
      }
      bestData = data
      if base64Length(forByteCount: data.count) <= maxBase64Length {
        return data
      }
      if currentQuality > CGFloat(minJpegQuality) / 100 {
        currentQuality = max(
          CGFloat(minJpegQuality) / 100,
          currentQuality - CGFloat(jpegQualityStep) / 100
        )
        continue
      }
      let nextMaxDimension = max(
        CGFloat(minImageDimension),
        (currentMaxDimension * CGFloat(imageDimensionStep)).rounded()
      )
      if nextMaxDimension == currentMaxDimension {
        return data
      }
      currentMaxDimension = nextMaxDimension
      currentQuality = initialQuality
    }
  }

  private func renderJpegData(
    from image: UIImage,
    maxDimension: CGFloat,
    quality: CGFloat
  ) -> Data? {
    let sourceSize = image.size
    guard sourceSize.width > 0, sourceSize.height > 0 else {
      return nil
    }
    let longestSide = max(sourceSize.width, sourceSize.height)
    let scale = min(maxDimension / longestSide, 1)
    let targetSize = CGSize(
      width: max(1, sourceSize.width * scale),
      height: max(1, sourceSize.height * scale)
    )
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = true
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    let jpegImage = renderer.image { context in
      context.cgContext.setFillColor(UIColor.white.cgColor)
      context.cgContext.fill(CGRect(origin: .zero, size: targetSize))
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return jpegImage.jpegData(compressionQuality: min(max(quality, 0.01), 1))
  }

  private func base64Length(forByteCount byteCount: Int) -> Int {
    return ((byteCount + 2) / 3) * 4
  }

  private func cleanBase64Value(_ value: String) -> String {
    let withoutPrefix = value.components(separatedBy: "base64,").last ?? value
    return withoutPrefix
      .replacingOccurrences(of: "\n", with: "")
      .replacingOccurrences(of: "\r", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private let photoMaxDimension = 480
  private let photoJpegQuality = 35
  private let photoMaxBase64Length = 45 * 1024
  private let minImageDimension = 220
  private let imageDimensionStep = 0.82
  private let minJpegQuality = 8
  private let maxJpegQuality = 100
  private let jpegQualityStep = 7
}

private final class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  private let completion: (String) -> Void
  private let session = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var completed = false

  init(completion: @escaping (String) -> Void) {
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    addCancelButton()
    requestCameraAccess()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.bounds
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if !completed {
      finish("")
    }
  }

  private func requestCameraAccess() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      configureSession()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          granted ? self?.configureSession() : self?.finish("")
        }
      }
    default:
      finish("")
    }
  }

  private func configureSession() {
    guard let device = AVCaptureDevice.default(for: .video) else {
      finish("")
      return
    }
    do {
      let input = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(input) else {
        finish("")
        return
      }
      session.addInput(input)
    } catch {
      finish("")
      return
    }

    let output = AVCaptureMetadataOutput()
    guard session.canAddOutput(output) else {
      finish("")
      return
    }
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: .main)
    output.metadataObjectTypes = availableMetadataTypes(from: output)

    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.frame = view.bounds
    layer.videoGravity = .resizeAspectFill
    previewLayer = layer
    view.layer.insertSublayer(layer, at: 0)

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.session.startRunning()
    }
  }

  private func availableMetadataTypes(from output: AVCaptureMetadataOutput) -> [AVMetadataObject.ObjectType] {
    let preferred: [AVMetadataObject.ObjectType] = [
      .qr,
      .code128,
      .code39,
      .code93,
      .ean13,
      .ean8,
      .upce,
      .pdf417,
      .dataMatrix,
    ]
    return preferred.filter { output.availableMetadataObjectTypes.contains($0) }
  }

  private func addCancelButton() {
    let button = UIButton(type: .system)
    button.setTitle("Cancelar", for: .normal)
    button.tintColor = .white
    button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    button.layer.cornerRadius = 8
    button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(cancelScan), for: .touchUpInside)
    view.addSubview(button)
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
    ])
  }

  @objc private func cancelScan() {
    finish("")
  }

  private func finish(_ value: String) {
    guard !completed else {
      return
    }
    completed = true
    session.stopRunning()
    completion(value)
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          let value = readable.stringValue else {
      return
    }
    finish(value)
  }
}
