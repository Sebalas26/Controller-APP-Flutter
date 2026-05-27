import '../../../../shared/native/controller_native_bridge.dart';

class PrintDeviceService {
  PrintDeviceService({ControllerNativeBridge? nativeBridge})
    : _nativeBridge = nativeBridge ?? ControllerNativeBridge();

  final ControllerNativeBridge _nativeBridge;

  Future<bool> hasBluetoothPrinter() {
    return _nativeBridge.hasBluetoothPrinter();
  }

  Future<bool> printPdfFile(String filePath, {required String jobName}) {
    return _nativeBridge.printPdfFile(filePath, jobName: jobName);
  }

  Future<bool> printSewooTest() {
    return _nativeBridge.printSewooTest();
  }

  Future<String> printSewooTestDiagnostics() {
    return _nativeBridge.printSewooTestDiagnostics();
  }

  Future<bool> openPdfFile(String filePath) {
    return _nativeBridge.openPdfFile(filePath);
  }
}
