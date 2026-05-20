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
          let data = image.jpegData(compressionQuality: 0.85) else {
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
}
