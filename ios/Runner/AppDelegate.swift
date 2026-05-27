import Flutter
import AVFoundation
import ExternalAccessory
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
    EAAccessoryManager.shared().registerForLocalNotifications()
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
        case "hasBluetoothPrinter":
          result(self?.hasSewooPrinter() ?? false)
        case "printPdfFile":
          self?.printPdfFile(call: call, result: result)
        case "printSewooTest":
          self?.printSewooTest(result: result)
        case "printSewooTestDiagnostics":
          self?.printSewooTestDiagnostics(result: result)
        case "openPdfFile":
          self?.openPdfFile(call: call, result: result)
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

  private func printPdfFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let filePath = arguments["filePath"] as? String,
          !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(false)
      return
    }

    let url = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      result(false)
      return
    }

    let resultLock = NSLock()
    var didReturnResult = false
    let finish: (Bool) -> Void = { printed in
      resultLock.lock()
      defer { resultLock.unlock() }
      guard !didReturnResult else {
        return
      }
      didReturnResult = true
      DispatchQueue.main.async {
        result(printed)
      }
    }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else {
        finish(false)
        return
      }
      guard let image = self.renderPdfFirstPage(url: url, targetWidth: Int(self.sewooTwoInchPrintWidth)) else {
        NSLog("[ControllerNative][Sewoo] No fue posible renderizar PDF como imagen")
        finish(false)
        return
      }
      DispatchQueue.main.async {
        self.printSewooImageWhenReady(image: image, finish: finish)
      }
    }

    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + self.sewooPrintTimeoutSeconds) {
      resultLock.lock()
      let alreadyReturned = didReturnResult
      resultLock.unlock()
      if !alreadyReturned {
        NSLog("[ControllerNative][Sewoo] Timeout imprimiendo en iOS despues de %.0f segundos", self.sewooPrintTimeoutSeconds)
        finish(false)
      }
    }
  }

  private func printSewooTest(result: @escaping FlutterResult) {
    let resultLock = NSLock()
    var didReturnResult = false
    let finish: (Bool) -> Void = { printed in
      resultLock.lock()
      defer { resultLock.unlock() }
      guard !didReturnResult else {
        return
      }
      didReturnResult = true
      DispatchQueue.main.async {
        result(printed)
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        finish(false)
        return
      }
      self.printSewooTextWhenReady(finish: finish)
    }

    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + self.sewooPrintTimeoutSeconds) {
      resultLock.lock()
      let alreadyReturned = didReturnResult
      resultLock.unlock()
      if !alreadyReturned {
        NSLog("[ControllerNative][Sewoo] Timeout en prueba SEWO iOS despues de %.0f segundos", self.sewooPrintTimeoutSeconds)
        finish(false)
      }
    }
  }

  private func printSewooTestDiagnostics(result: @escaping FlutterResult) {
    let resultLock = NSLock()
    var didReturnResult = false
    var lines: [String] = ["INICIO diagnostico SEWO iOS"]
    let append: (String) -> Void = { line in
      resultLock.lock()
      lines.append(line)
      resultLock.unlock()
    }
    let finish: (String) -> Void = { finalLine in
      resultLock.lock()
      defer { resultLock.unlock() }
      guard !didReturnResult else {
        return
      }
      didReturnResult = true
      lines.append(finalLine)
      let message = lines.joined(separator: "\n")
      DispatchQueue.main.async {
        result(message)
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        finish("RESULTADO: ERROR - AppDelegate liberado")
        return
      }
      append(self.sewooAccessoryDiagnostics())
      guard !self.hasSewooPrinter() else {
        append("Accesorio SEWO visible para esta app.")
        DispatchQueue.global(qos: .userInitiated).async {
          let message = self.printSewooTextDiagnosticLines(append: append)
          finish(message)
        }
        return
      }

      append("No hay accesorio SEWO visible. Abriendo selector MFi/Bluetooth...")
      EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { [weak self] error in
        guard let self = self else {
          finish("RESULTADO: ERROR - AppDelegate liberado despues del selector")
          return
        }
        if let error = error {
          append("Selector MFi retorno: \(error.localizedDescription)")
        } else {
          append("Selector MFi retorno sin error.")
        }
        append(self.sewooAccessoryDiagnostics())
        guard self.hasSewooPrinter() else {
          finish("RESULTADO: ERROR - LK-P25 no visible para esta app despues del selector")
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let message = self.printSewooTextDiagnosticLines(append: append)
          finish(message)
        }
      }
    }

    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + self.sewooPrintTimeoutSeconds) {
      resultLock.lock()
      let alreadyReturned = didReturnResult
      resultLock.unlock()
      if !alreadyReturned {
        finish("RESULTADO: ERROR - Timeout despues de \(Int(self.sewooPrintTimeoutSeconds)) segundos")
      }
    }
  }

  private func openPdfFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let filePath = arguments["filePath"] as? String,
          !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(false)
      return
    }

    let url = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      result(false)
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let rootViewController = self?.window?.rootViewController else {
        result(false)
        return
      }
      let activityController = UIActivityViewController(
        activityItems: [url],
        applicationActivities: nil
      )
      if let popover = activityController.popoverPresentationController {
        popover.sourceView = rootViewController.view
        popover.sourceRect = rootViewController.view.bounds
      }
      rootViewController.present(activityController, animated: true) {
        result(true)
      }
    }
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

  private func hasSewooPrinter() -> Bool {
    EAAccessoryManager.shared().registerForLocalNotifications()
    return sewooAccessory() != nil
  }

  private func sewooAccessory() -> EAAccessory? {
    return EAAccessoryManager.shared().connectedAccessories.first { accessory in
      accessory.protocolStrings.contains(sewooProtocol)
    }
  }

  private func sewooAccessoryDiagnostics() -> String {
    EAAccessoryManager.shared().registerForLocalNotifications()
    let accessories = EAAccessoryManager.shared().connectedAccessories
    if accessories.isEmpty {
      return "Accesorios iOS: ninguno reportado por ExternalAccessory"
    }
    let details = accessories.map { accessory in
      let protocols = accessory.protocolStrings.isEmpty
        ? "sin protocolos"
        : accessory.protocolStrings.joined(separator: ",")
      return "- \(accessory.manufacturer) \(accessory.name) conectado=\(accessory.isConnected) protocolos=\(protocols)"
    }
    return "Accesorios iOS:\n" + details.joined(separator: "\n")
  }

  private func logSewooAccessories() {
    let accessories = EAAccessoryManager.shared().connectedAccessories
    if accessories.isEmpty {
      NSLog("[ControllerNative][Sewoo] iOS no reporta accesorios ExternalAccessory conectados")
      return
    }
    for accessory in accessories {
      NSLog(
        "[ControllerNative][Sewoo] Accesorio iOS: %@ %@ protocolos=%@ conectado=%@",
        accessory.manufacturer,
        accessory.name,
        accessory.protocolStrings.joined(separator: ","),
        accessory.isConnected ? "true" : "false"
      )
    }
  }

  private func printSewooImageWhenReady(image: UIImage, finish: @escaping (Bool) -> Void) {
    logSewooAccessories()
    guard !hasSewooPrinter() else {
      DispatchQueue.global(qos: .userInitiated).async {
        finish(self.printSewooImage(image))
      }
      return
    }

    NSLog("[ControllerNative][Sewoo] No hay accesorio Sewoo conectado. Abriendo selector MFi iOS")
    EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { [weak self] error in
      guard let self = self else {
        finish(false)
        return
      }
      if let error = error {
        NSLog("[ControllerNative][Sewoo] Selector MFi retorno error: %@", error.localizedDescription)
      }
      self.logSewooAccessories()
      guard self.hasSewooPrinter() else {
        NSLog("[ControllerNative][Sewoo] La LK-P25 no quedo conectada despues del selector MFi")
        finish(false)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        finish(self.printSewooImage(image))
      }
    }
  }

  private func printSewooTextWhenReady(finish: @escaping (Bool) -> Void) {
    logSewooAccessories()
    guard !hasSewooPrinter() else {
      finish(printSewooText())
      return
    }

    NSLog("[ControllerNative][Sewoo] Prueba: no hay accesorio conectado. Abriendo selector MFi iOS")
    EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { [weak self] error in
      guard let self = self else {
        finish(false)
        return
      }
      if let error = error {
        NSLog("[ControllerNative][Sewoo] Prueba selector MFi retorno error: %@", error.localizedDescription)
      }
      self.logSewooAccessories()
      guard self.hasSewooPrinter() else {
        NSLog("[ControllerNative][Sewoo] Prueba: LK-P25 no conectada despues del selector")
        finish(false)
        return
      }
      finish(self.printSewooText())
    }
  }

  private func printSewooImage(_ image: UIImage) -> Bool {
    NSLog("[ControllerNative][Sewoo] Preparando etiqueta raster ESC/POS para iOS")
    guard let bytes = escposRasterBytes(for: image) else {
      NSLog("[ControllerNative][Sewoo] No fue posible convertir la etiqueta a raster ESC/POS")
      return false
    }

    NSLog("[ControllerNative][Sewoo] Enviando etiqueta por EASession directa (%ld bytes)", bytes.count)
    if let error = writeSewooEscposBytesUsingEASession(
      bytes,
      append: { line in NSLog("[ControllerNative][Sewoo] %@", line) },
      writeTimeout: sewooImageWriteTimeoutSeconds
    ) {
      NSLog("[ControllerNative][Sewoo] Error imprimiendo etiqueta por EASession: %@", error)
      return false
    }
    return true
  }

  private func printSewooText() -> Bool {
    return writeSewooRawTextUsingEASession(append: { _ in }) == nil
  }

  private func printSewooTextDiagnosticLines(append: @escaping (String) -> Void) -> String {
    var lines: [String] = []
    let collect: (String) -> Void = { line in
      lines.append(line)
      append(line)
    }
    collect("Abriendo sesion EASession directa de Apple...")
    if let error = writeSewooRawTextUsingEASession(append: collect) {
      lines.append("RESULTADO: ERROR - \(error)")
    } else {
      lines.append("RESULTADO: OK")
    }
    return lines.joined(separator: "\n")
  }

  private func writeSewooRawTextUsingEASession(append: (String) -> Void) -> String? {
    var bytes: [UInt8] = []
    bytes += [0x1B, 0x40]
    bytes += [0x1B, 0x61, 0x01]
    bytes += Array("Controller App\r\nPrueba SEWO LK-P25\r\niOS RAW\r\n".utf8)
    bytes += [0x0A, 0x0A, 0x0A, 0x0A]
    return writeSewooEscposBytesUsingEASession(
      bytes,
      append: append,
      writeTimeout: sewooTextWriteTimeoutSeconds
    )
  }

  private func writeSewooEscposBytesUsingEASession(
    _ bytes: [UInt8],
    append: (String) -> Void,
    writeTimeout: TimeInterval
  ) -> String? {
    guard let accessory = sewooAccessory() else {
      return "No hay accesorio con protocolo \(sewooProtocol)"
    }

    append("Creando EASession para \(accessory.name)...")
    guard let session = EASession(accessory: accessory, forProtocol: sewooProtocol) else {
      return "EASession devolvio nil"
    }
    guard let outputStream = session.outputStream else {
      return "EASession no entrego outputStream"
    }

    append("Abriendo outputStream...")
    outputStream.schedule(in: .current, forMode: .default)
    outputStream.open()

    let openDeadline = Date().addingTimeInterval(sewooStreamOpenTimeoutSeconds)
    while outputStream.streamStatus == .opening && Date() < openDeadline {
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }

    append("outputStream status=\(streamStatusDescription(outputStream.streamStatus))")
    if let error = outputStream.streamError {
      append("outputStream error=\(error.localizedDescription)")
    }
    guard outputStream.streamStatus == .open else {
      outputStream.close()
      outputStream.remove(from: .current, forMode: .default)
      return "outputStream no abrio"
    }

    append("Enviando \(bytes.count) bytes ESC/POS...")
    var sent = 0
    let writeDeadline = Date().addingTimeInterval(writeTimeout)
    while sent < bytes.count && Date() < writeDeadline {
      let wrote = bytes.withUnsafeBufferPointer { buffer -> Int in
        guard let baseAddress = buffer.baseAddress else {
          return -1
        }
        return outputStream.write(
          baseAddress.advanced(by: sent),
          maxLength: bytes.count - sent
        )
      }
      if wrote > 0 {
        sent += wrote
        continue
      }
      if wrote < 0 {
        let error = outputStream.streamError?.localizedDescription ?? "sin detalle"
        outputStream.close()
        outputStream.remove(from: .current, forMode: .default)
        return "write fallo: \(error)"
      }
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }

    append("bytes enviados=\(sent)/\(bytes.count)")
    if sent == bytes.count {
      Thread.sleep(forTimeInterval: sewooPostWriteDelaySeconds)
    }
    outputStream.close()
    outputStream.remove(from: .current, forMode: .default)
    if sent < bytes.count {
      return "timeout escribiendo bytes"
    }
    return nil
  }

  private func escposRasterBytes(for image: UIImage) -> [UInt8]? {
    guard let raster = oneBitRasterImage(for: image, targetWidth: Int(sewooTwoInchPrintWidth)) else {
      return nil
    }

    let xLow = UInt8(raster.bytesPerRow & 0xFF)
    let xHigh = UInt8((raster.bytesPerRow >> 8) & 0xFF)
    var bytes: [UInt8] = []
    bytes.reserveCapacity(raster.data.count + 128)
    bytes += [0x1B, 0x40]
    bytes += [0x1B, 0x61, 0x01]

    var row = 0
    while row < raster.height {
      let rows = min(sewooRasterChunkRows, raster.height - row)
      let yLow = UInt8(rows & 0xFF)
      let yHigh = UInt8((rows >> 8) & 0xFF)
      bytes += [0x1D, 0x76, 0x30, 0x00, xLow, xHigh, yLow, yHigh]

      let start = row * raster.bytesPerRow
      let end = start + (rows * raster.bytesPerRow)
      bytes += raster.data[start..<end]
      row += rows
    }

    bytes += [0x1B, 0x32]
    bytes += [0x0A, 0x0A, 0x0A, 0x0A]
    return bytes
  }

  private func oneBitRasterImage(for image: UIImage, targetWidth: Int) -> SewooRasterImage? {
    guard let cgImage = image.cgImage, image.size.width > 0, image.size.height > 0 else {
      return nil
    }

    let width = max(8, targetWidth - (targetWidth % 8))
    let height = max(1, Int(ceil((CGFloat(width) / image.size.width) * image.size.height)))
    let bytesPerPixel = 4
    let pixelBytesPerRow = width * bytesPerPixel
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixels = [UInt8](repeating: 255, count: pixelBytesPerRow * height)

    let drawn = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
      guard let baseAddress = rawBuffer.baseAddress,
            let context = CGContext(
              data: baseAddress,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: pixelBytesPerRow,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
        return false
      }

      let rect = CGRect(x: 0, y: 0, width: width, height: height)
      context.setFillColor(UIColor.white.cgColor)
      context.fill(rect)
      context.interpolationQuality = .high
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      context.draw(cgImage, in: rect)
      return true
    }
    guard drawn else {
      return nil
    }

    let rasterBytesPerRow = width / 8
    var raster = [UInt8](repeating: 0, count: rasterBytesPerRow * height)
    for y in 0..<height {
      for x in 0..<width {
        let sourceY = height - 1 - y
        let pixelIndex = (sourceY * pixelBytesPerRow) + (x * bytesPerPixel)
        let red = Int(pixels[pixelIndex])
        let green = Int(pixels[pixelIndex + 1])
        let blue = Int(pixels[pixelIndex + 2])
        let luminance = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        if luminance < sewooRasterThreshold {
          let byteIndex = (y * rasterBytesPerRow) + (x / 8)
          raster[byteIndex] |= UInt8(0x80 >> (x % 8))
        }
      }
    }

    return SewooRasterImage(
      height: height,
      bytesPerRow: rasterBytesPerRow,
      data: raster
    )
  }

  private func streamStatusDescription(_ status: Stream.Status) -> String {
    switch status {
    case .notOpen:
      return "notOpen"
    case .opening:
      return "opening"
    case .open:
      return "open"
    case .reading:
      return "reading"
    case .writing:
      return "writing"
    case .atEnd:
      return "atEnd"
    case .closed:
      return "closed"
    case .error:
      return "error"
    @unknown default:
      return "unknown"
    }
  }

  private func renderPdfFirstPage(url: URL, targetWidth: Int) -> UIImage? {
    guard let document = CGPDFDocument(url as CFURL),
          let page = document.page(at: 1) else {
      return nil
    }

    let pageRect = page.getBoxRect(.mediaBox)
    guard pageRect.width > 0, pageRect.height > 0, targetWidth > 0 else {
      return nil
    }

    let scale = CGFloat(targetWidth) / pageRect.width
    let targetSize = CGSize(
      width: CGFloat(targetWidth),
      height: ceil(pageRect.height * scale)
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1

    return UIGraphicsImageRenderer(size: targetSize, format: format).image { rendererContext in
      UIColor.white.setFill()
      rendererContext.fill(CGRect(origin: .zero, size: targetSize))
      let context = rendererContext.cgContext
      context.translateBy(x: 0, y: targetSize.height)
      context.scaleBy(x: scale, y: -scale)
      context.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
      context.drawPDFPage(page)
    }
  }

  private let photoMaxDimension = 480
  private let photoJpegQuality = 35
  private let photoMaxBase64Length = 45 * 1024
  private let minImageDimension = 220
  private let imageDimensionStep = 0.82
  private let minJpegQuality = 8
  private let maxJpegQuality = 100
  private let jpegQualityStep = 7
  private struct SewooRasterImage {
    let height: Int
    let bytesPerRow: Int
    let data: [UInt8]
  }

  private let sewooProtocol = "com.mobileprinter.datapath"
  private let sewooTwoInchPrintWidth: Int32 = 384
  private let sewooPrintTimeoutSeconds: Double = 30
  private let sewooStreamOpenTimeoutSeconds: TimeInterval = 4
  private let sewooTextWriteTimeoutSeconds: TimeInterval = 4
  private let sewooImageWriteTimeoutSeconds: TimeInterval = 20
  private let sewooPostWriteDelaySeconds: TimeInterval = 0.7
  private let sewooRasterChunkRows = 128
  private let sewooRasterThreshold = 190
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
