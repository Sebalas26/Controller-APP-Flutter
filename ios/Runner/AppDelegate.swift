import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private var pendingPhotoResult: FlutterResult?

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
        case "getAesPasswordSecret", "getAesKeySecret", "getAesSaltSecret":
          result("")
        case "takePackagePhoto":
          self?.takePackagePhoto(result: result)
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
            quality: CGFloat(photoJpegQuality) / 100
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

  private func compressImageBase64ToJpeg(call: FlutterMethodCall, result: FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let imageBase64 = arguments["imageBase64"] as? String,
          !imageBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result("")
      return
    }

    let maxDimension = arguments["maxDimension"] as? Int ?? photoMaxDimension
    let quality = arguments["quality"] as? Int ?? photoJpegQuality
    let cleanBase64 = cleanBase64Value(imageBase64)
    guard let inputData = Data(base64Encoded: cleanBase64),
          let image = UIImage(data: inputData),
          let outputData = compressedJpegData(
            from: image,
            maxDimension: CGFloat(max(1, maxDimension)),
            quality: CGFloat(min(max(quality, minJpegQuality), maxJpegQuality)) / 100
          ) else {
      result("")
      return
    }
    result(outputData.base64EncodedString())
  }

  private func compressedJpegData(
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

  private func cleanBase64Value(_ value: String) -> String {
    let withoutPrefix = value.components(separatedBy: "base64,").last ?? value
    return withoutPrefix
      .replacingOccurrences(of: "\n", with: "")
      .replacingOccurrences(of: "\r", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private let photoMaxDimension = 960
  private let photoJpegQuality = 50
  private let minJpegQuality = 1
  private let maxJpegQuality = 100
}
