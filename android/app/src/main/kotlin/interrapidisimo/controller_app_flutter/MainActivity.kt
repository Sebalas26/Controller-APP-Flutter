package interrapidisimo.controller_app_flutter

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.CancellationSignal
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.Settings
import android.provider.MediaStore
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.util.Base64
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.sewoo.jpos.command.ESCPOSConst
import com.sewoo.jpos.printer.ESCPOSPrinter
import com.sewoo.jpos.printer.LKPrint
import com.sewoo.port.android.BluetoothPort
import com.sewoo.request.android.RequestHandler
import com.google.zxing.integration.android.IntentIntegrator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private var pendingPhotoResult: MethodChannel.Result? = null
    private var pendingQrResult: MethodChannel.Result? = null
    private var pendingBluetoothPrintCall: MethodCall? = null
    private var pendingBluetoothPrintResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "controller_app/native"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidId" -> result.success(
                    Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: ""
                )
                "getAesPasswordSecret" -> result.success(BuildConfig.ENCRYPT_AES256_PASSWORD_SECRET)
                "getAesKeySecret" -> result.success(BuildConfig.ENCRYPT_AES256_KEY_SECRET)
                "getAesSaltSecret" -> result.success(BuildConfig.ENCRYPT_AES256_SALT_SECRET)
                "takePackagePhoto" -> takePackagePhoto(result)
                "scanQrCode" -> scanQrCode(result)
                "compressImageBase64ToJpeg" -> compressImageBase64ToJpeg(call, result)
                "getYaapUser" -> result.success(BuildConfig.YAAP_USER)
                "getYaapPasswordPruebas" -> result.success(BuildConfig.YAAP_PASSWORD_PRUEBAS)
                "getYaapPasswordQa" -> result.success(BuildConfig.YAAP_PASSWORD_QA)
                "getYaapPasswordProduccion" -> result.success(BuildConfig.YAAP_PASSWORD)
                "hasBluetoothPrinter" -> result.success(hasBluetoothPrinter())
                "printPdfFile" -> printPdfFile(call, result)
                "printSewooTest" -> printSewooTest(call, result)
                "printSewooTestDiagnostics" -> printSewooTestDiagnostics(call, result)
                "openPdfFile" -> openPdfFile(call, result)
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PACKAGE_PHOTO) {
            handlePackagePhotoResult(resultCode, data)
            return
        }

        val scanResult = IntentIntegrator.parseActivityResult(requestCode, resultCode, data)
        if (scanResult != null) {
            val pending = pendingQrResult
            pendingQrResult = null
            pending?.success(scanResult.contents.orEmpty())
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_BLUETOOTH_PRINT) {
            val pendingCall = pendingBluetoothPrintCall
            val pendingResult = pendingBluetoothPrintResult
            pendingBluetoothPrintCall = null
            pendingBluetoothPrintResult = null
            if (pendingCall == null || pendingResult == null) return

            if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                if (pendingCall.method == "printSewooTest") {
                    printSewooTest(pendingCall, pendingResult)
                } else if (pendingCall.method == "printSewooTestDiagnostics") {
                    printSewooTestDiagnostics(pendingCall, pendingResult)
                } else {
                    printPdfFile(pendingCall, pendingResult)
                }
            } else {
                pendingResult.success(false)
            }
            return
        }

        if (requestCode != PERMISSION_REQUEST_CAMERA) return

        val pending = pendingPhotoResult ?: return
        
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            launchCameraIntent(pending)
        } else {
            pendingPhotoResult = null
            try {
                pending.error("PERMISSION_DENIED", "Permiso de cámara denegado", null)
            } catch (e: Exception) {
                // Result already consumed
            }
        }
    }

    private fun takePackagePhoto(result: MethodChannel.Result) {
        try {
            if (pendingPhotoResult != null) {
                result.error("CAMERA_BUSY", "Ya hay una captura en proceso.", null)
                return
            }
            
            // Check camera availability
            if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA)) {
                result.success("")
                return
            }

            // Check and request permission
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA)
                    == PackageManager.PERMISSION_GRANTED
                ) {
                    pendingPhotoResult = result
                    launchCameraIntent(result)
                } else {
                    pendingPhotoResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(android.Manifest.permission.CAMERA),
                        PERMISSION_REQUEST_CAMERA
                    )
                }
            } else {
                pendingPhotoResult = result
                launchCameraIntent(result)
            }
        } catch (e: Exception) {
            pendingPhotoResult = null
            try {
                result.error("CAMERA_ERROR", e.message ?: "Error al abrir cámara", null)
            } catch (e2: Exception) {
                // Result already consumed
            }
        }
    }

    private fun scanQrCode(result: MethodChannel.Result) {
        try {
            if (pendingQrResult != null || pendingPhotoResult != null) {
                result.error("CAMERA_BUSY", "Ya hay una captura en proceso.", null)
                return
            }
            if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA)) {
                result.success("")
                return
            }
            pendingQrResult = result
            IntentIntegrator(this).apply {
                setDesiredBarcodeFormats(IntentIntegrator.ALL_CODE_TYPES)
                setPrompt("Escanea la guia")
                setCameraId(0)
                setBeepEnabled(true)
                setBarcodeImageEnabled(false)
                setOrientationLocked(false)
                initiateScan()
            }
        } catch (e: Exception) {
            pendingQrResult = null
            try {
                result.error("QR_SCAN_ERROR", e.message ?: "Error al iniciar escaner", null)
            } catch (e2: Exception) {
                // Result already consumed
            }
        }
    }

    private fun handlePackagePhotoResult(resultCode: Int, data: Intent?) {
        val pending = pendingPhotoResult
        pendingPhotoResult = null

        if (pending == null) return

        try {
            if (resultCode != Activity.RESULT_OK) {
                pending.success("")
                return
            }

            val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                data?.extras?.getParcelable("data", Bitmap::class.java)
            } else {
                @Suppress("DEPRECATION")
                data?.extras?.getParcelable("data") as? Bitmap
            }

            if (bitmap == null) {
                pending.success("")
                return
            }

            val jpegBase64 = bitmapToJpegBase64(
                bitmap,
                PHOTO_MAX_DIMENSION,
                PHOTO_JPEG_QUALITY,
                PHOTO_MAX_BASE64_LENGTH
            )
            pending.success(jpegBase64)
        } catch (e: Exception) {
            try {
                pending.success("")
            } catch (e2: Exception) {
                // Result already consumed
            }
        }
    }

    private fun launchCameraIntent(result: MethodChannel.Result) {
        try {
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            if (intent.resolveActivity(packageManager) == null) {
                pendingPhotoResult = null
                try {
                    result.success("")
                } catch (e: Exception) {
                    // Result already consumed
                }
                return
            }
            startActivityForResult(intent, REQUEST_PACKAGE_PHOTO)
        } catch (e: Exception) {
            pendingPhotoResult = null
            try {
                result.error("CAMERA_LAUNCH_ERROR", e.message ?: "Error al iniciar cámara", null)
            } catch (e2: Exception) {
                // Result already consumed
            }
        }
    }


    private fun compressImageBase64ToJpeg(call: MethodCall, result: MethodChannel.Result) {
        try {
            val imageBase64 = call.argument<String>("imageBase64").orEmpty()
            if (imageBase64.isBlank()) {
                result.success("")
                return
            }
            val bytes = Base64.decode(cleanBase64(imageBase64), Base64.DEFAULT)
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            if (bitmap == null) {
                result.success("")
                return
            }
            result.success(
                bitmapToJpegBase64(
                    bitmap,
                    call.argument<Int>("maxDimension") ?: PHOTO_MAX_DIMENSION,
                    call.argument<Int>("quality") ?: PHOTO_JPEG_QUALITY,
                    call.argument<Int>("maxBase64Length") ?: PHOTO_MAX_BASE64_LENGTH
                )
            )
        } catch (e: IllegalArgumentException) {
            try {
                result.success("")
            } catch (e2: Exception) {
                // Result already consumed
            }
        } catch (e: Exception) {
            try {
                result.success("")
            } catch (e2: Exception) {
                // Result already consumed
            }
        }
    }

    private fun bitmapToJpegBase64(
        bitmap: Bitmap,
        maxDimension: Int,
        quality: Int,
        maxBase64Length: Int
    ): String {
        val safeMaxBase64Length = maxBase64Length.coerceAtLeast(1)
        val initialQuality = quality.coerceIn(MIN_JPEG_QUALITY, MAX_JPEG_QUALITY)
        var currentMaxDimension = maxDimension.coerceAtLeast(MIN_IMAGE_DIMENSION)
        var currentQuality = initialQuality
        var bestEncoded = ""

        while (true) {
            val scaled = scaleBitmap(bitmap, currentMaxDimension)
            val flattened = Bitmap.createBitmap(scaled.width, scaled.height, Bitmap.Config.RGB_565)
            Canvas(flattened).apply {
                drawColor(Color.WHITE)
                drawBitmap(scaled, 0f, 0f, null)
            }
            val output = ByteArrayOutputStream()
            flattened.compress(Bitmap.CompressFormat.JPEG, currentQuality, output)
            bestEncoded = Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
            if (scaled !== bitmap) {
                scaled.recycle()
            }
            flattened.recycle()

            if (bestEncoded.length <= safeMaxBase64Length) {
                return bestEncoded
            }

            if (currentQuality > MIN_JPEG_QUALITY) {
                currentQuality = (currentQuality - JPEG_QUALITY_STEP).coerceAtLeast(MIN_JPEG_QUALITY)
                continue
            }

            val nextMaxDimension = (currentMaxDimension * IMAGE_DIMENSION_STEP).roundToInt()
                .coerceAtLeast(MIN_IMAGE_DIMENSION)
            if (nextMaxDimension == currentMaxDimension) {
                return bestEncoded
            }
            currentMaxDimension = nextMaxDimension
            currentQuality = initialQuality
        }
    }

    private fun scaleBitmap(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val safeMaxDimension = maxDimension.coerceAtLeast(1)
        val longestSide = maxOf(bitmap.width, bitmap.height)
        if (longestSide <= safeMaxDimension) return bitmap
        val scale = safeMaxDimension.toFloat() / longestSide.toFloat()
        val width = (bitmap.width * scale).roundToInt().coerceAtLeast(1)
        val height = (bitmap.height * scale).roundToInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }

    private fun cleanBase64(value: String): String {
        return value.substringAfter("base64,", value)
            .replace("\n", "")
            .replace("\r", "")
            .trim()
    }

    private fun hasBluetoothPrinter(): Boolean {
        return findSewooPrinterDevices().isNotEmpty()
    }

    private fun isBluetoothDeviceConnected(device: android.bluetooth.BluetoothDevice): Boolean {
        return try {
            val method = device.javaClass.getMethod("isConnected")
            method.invoke(device) as? Boolean ?: false
        } catch (_: Exception) {
            false
        }
    }

    private fun printPdfFile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val file = File(call.argument<String>("filePath").orEmpty())
            if (!file.exists() || !file.isFile) {
                result.success(false)
                return
            }
            if (!ensureBluetoothPrintPermission(call, result)) return

            Thread {
                val printed = try {
                    printSewooPdfFile(file)
                } catch (_: Exception) {
                    false
                }
                runOnUiThread { result.success(printed) }
            }.start()
        } catch (e: Exception) {
            result.error("PRINT_ERROR", e.message ?: "No fue posible imprimir", null)
        }
    }

    private fun printSewooTest(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (!ensureBluetoothPrintPermission(call, result)) return

            Thread {
                val printed = try {
                    printSewooTestTicket()
                } catch (_: Exception) {
                    false
                }
                runOnUiThread { result.success(printed) }
            }.start()
        } catch (e: Exception) {
            result.error("PRINT_TEST_ERROR", e.message ?: "No fue posible imprimir prueba SEWO", null)
        }
    }

    private fun printSewooTestDiagnostics(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (!ensureBluetoothPrintPermission(call, result)) return

            Thread {
                val devices = findSewooPrinterDevices()
                val printed = try {
                    printSewooTestTicket()
                } catch (_: Exception) {
                    false
                }
                val message = buildString {
                    appendLine("INICIO diagnostico SEWO Android")
                    appendLine("Dispositivos candidatos: ${devices.size}")
                    devices.forEach { device ->
                        appendLine("- ${device.name.orEmpty()} ${device.address}")
                    }
                    appendLine(if (printed) "RESULTADO: OK" else "RESULTADO: ERROR - prueba no impresa")
                }
                runOnUiThread { result.success(message) }
            }.start()
        } catch (e: Exception) {
            result.error("PRINT_TEST_ERROR", e.message ?: "No fue posible diagnosticar SEWO", null)
        }
    }

    private fun ensureBluetoothPrintPermission(
        call: MethodCall,
        result: MethodChannel.Result
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val requiredPermissions = requiredBluetoothPrintPermissions()
        val missingPermissions = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missingPermissions.isEmpty()) return true
        if (pendingBluetoothPrintResult != null) {
            result.success(false)
            return false
        }
        pendingBluetoothPrintCall = call
        pendingBluetoothPrintResult = result
        ActivityCompat.requestPermissions(
            this,
            missingPermissions.toTypedArray(),
            PERMISSION_REQUEST_BLUETOOTH_PRINT
        )
        return false
    }

    private fun printSewooPdfFile(file: File): Boolean {
        val devices = findSewooPrinterDevices()
        if (devices.isEmpty()) return false

        for (device in devices) {
            if (printSewooPdfFileToDevice(file, device)) return true
        }
        return false
    }

    private fun printSewooTestTicket(): Boolean {
        val devices = findSewooPrinterDevices()
        if (devices.isEmpty()) return false

        for (device in devices) {
            for (mode in SewooConnectMode.entries) {
                if (printSewooTestToDevice(device, mode)) return true
            }
        }
        return false
    }

    private fun printSewooTestToDevice(device: BluetoothDevice, mode: SewooConnectMode): Boolean {
        val bluetoothPort = BluetoothPort.getInstance()
        bluetoothPort.SetMacFilter(false)
        var requestThread: Thread? = null
        return try {
            if (bluetoothPort.isConnected()) {
                bluetoothPort.disconnect()
            }
            Log.d(
                TAG,
                "Intentando prueba SEWO ${mode.name}: ${device.name.orEmpty()} - ${device.address}"
            )
            when (mode) {
                SewooConnectMode.DEFAULT -> bluetoothPort.connect(device)
                SewooConnectMode.INSECURE -> bluetoothPort.connectInsecure(device)
                SewooConnectMode.SECURE -> bluetoothPort.connectSecure(device)
            }
            requestThread = Thread(RequestHandler()).apply { start() }
            Thread.sleep(700)

            val printer = ESCPOSPrinter()
            printer.printText(
                "Controller App\nPrueba SEWO LK-P25\nAndroid\n",
                LKPrint.LK_ALIGNMENT_CENTER,
                ESCPOSConst.LK_FNT_DEFAULT,
                ESCPOSConst.LK_TXT_1WIDTH
            )
            printer.lineFeed(4)
            true
        } catch (exception: Exception) {
            Log.w(TAG, "Prueba SEWO fallo en ${device.address} con ${mode.name}: ${exception.message}")
            false
        } finally {
            try {
                if (bluetoothPort.isConnected()) bluetoothPort.disconnect()
            } catch (_: Exception) {
                // Ignore disconnect errors.
            }
            requestThread?.interrupt()
        }
    }

    private fun printSewooPdfFileToDevice(file: File, device: BluetoothDevice): Boolean {
        val modes = listOf(
            SewooConnectMode.DEFAULT,
            SewooConnectMode.INSECURE,
            SewooConnectMode.SECURE
        )
        for (mode in modes) {
            if (printSewooPdfFileToDevice(file, device, mode)) return true
        }
        return false
    }

    private fun printSewooPdfFileToDevice(
        file: File,
        device: BluetoothDevice,
        mode: SewooConnectMode
    ): Boolean {
        val bluetoothPort = BluetoothPort.getInstance()
        bluetoothPort.SetMacFilter(false)
        var requestThread: Thread? = null
        return try {
            if (bluetoothPort.isConnected()) {
                bluetoothPort.disconnect()
            }
            Log.d(
                TAG,
                "Intentando imprimir en Bluetooth ${mode.name}: ${device.name.orEmpty()} - ${device.address}"
            )
            when (mode) {
                SewooConnectMode.DEFAULT -> bluetoothPort.connect(device)
                SewooConnectMode.INSECURE -> bluetoothPort.connectInsecure(device)
                SewooConnectMode.SECURE -> bluetoothPort.connectSecure(device)
            }
            requestThread = Thread(RequestHandler()).apply { start() }
            Thread.sleep(700)

            val printer = ESCPOSPrinter()
            val status = sewooPrinterStatus(printer)
            if (status != ESCPOSConst.LK_SUCCESS) return false

            printPdfToSewooPrinter(
                printer = printer,
                file = file,
                alignment = LKPrint.LK_ALIGNMENT_CENTER,
                paperSize = LKPrint.LK_PAPER_2INCH,
                feed = 2
            )
        } catch (exception: Exception) {
            Log.w(TAG, "No fue posible imprimir en ${device.address} con ${mode.name}: ${exception.message}")
            false
        } finally {
            try {
                if (bluetoothPort.isConnected()) bluetoothPort.disconnect()
            } catch (_: Exception) {
                // Ignore disconnect errors.
            }
            requestThread?.interrupt()
        }
    }

    private fun findSewooPrinterDevices(): List<BluetoothDevice> {
        return try {
            val adapter = bluetoothAdapter() ?: return emptyList()
            if (!adapter.isEnabled || !hasBluetoothConnectPermission()) return emptyList()
            val bluetoothPort = BluetoothPort.getInstance()
            bluetoothPort.SetMacFilter(false)
            val bondedDevices = adapter.bondedDevices
                .filter { device -> bluetoothPort.isValidAddress(device.address) }
            val preferredDevices = bondedDevices.filter { device -> looksLikeSewooPrinter(device) }
            val fallbackDevices = bondedDevices.filterNot { device ->
                preferredDevices.any { preferred -> preferred.address == device.address }
            }
            (preferredDevices + fallbackDevices).distinctBy { device -> device.address }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getSystemService(BluetoothManager::class.java)?.adapter
        } else {
            @Suppress("DEPRECATION")
            BluetoothAdapter.getDefaultAdapter()
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            requiredBluetoothPrintPermissions().all {
                ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
            }
    }

    private fun requiredBluetoothPrintPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                android.Manifest.permission.BLUETOOTH_CONNECT,
                android.Manifest.permission.BLUETOOTH_SCAN
            )
        } else {
            emptyArray()
        }
    }

    private fun looksLikeSewooPrinter(device: BluetoothDevice): Boolean {
        val majorClass = device.bluetoothClass?.majorDeviceClass
        val name = device.name.orEmpty()
        return majorClass == BluetoothClass.Device.Major.IMAGING ||
            name.contains("SW_", ignoreCase = true) ||
            name.contains("SEWOO", ignoreCase = true) ||
            name.contains("LK-P", ignoreCase = true) ||
            name.contains("LK", ignoreCase = true) ||
            name.contains("printer", ignoreCase = true) ||
            name.contains("impresora", ignoreCase = true)
    }

    private fun sewooPrinterStatus(posPtr: ESCPOSPrinter): Int {
        val returnValue = posPtr.printerCheck()
        if (returnValue == ESCPOSConst.LK_SUCCESS) {
            val status = posPtr.status()
            if (status == ESCPOSConst.LK_STS_NORMAL) {
                return ESCPOSConst.LK_SUCCESS
            }
            if ((ESCPOSConst.LK_STS_COVER_OPEN and status) > 0) return ESCPOSConst.LK_STS_COVER_OPEN
            if ((ESCPOSConst.LK_STS_PAPER_EMPTY and status) > 0) return ESCPOSConst.LK_STS_PAPER_EMPTY
            if ((ESCPOSConst.LK_STS_BATTERY_LOW and status) > 0) return ESCPOSConst.LK_STS_BATTERY_LOW
        }
        return returnValue
    }

    private fun printPdfToSewooPrinter(
        printer: ESCPOSPrinter,
        file: File,
        alignment: Int,
        paperSize: Int,
        feed: Int
    ): Boolean {
        if (!file.exists() || Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return false
        }

        val sdkPdfResult = try {
            printer.printPDFFile(file, 1, paperSize, alignment)
        } catch (_: Exception) {
            -1
        }
        if (sdkPdfResult == ESCPOSConst.LK_SUCCESS) {
            printer.lineFeed(feed)
            return true
        }

        val pdfDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(pdfDescriptor)
        val page = renderer.openPage(0)
        try {
            var pageWidth = page.width * 6
            var pageHeight = page.height * 6

            if (pageHeight > MAX_SEWOO_BITMAP_SIZE) {
                pageWidth = (MAX_SEWOO_BITMAP_SIZE.toDouble() / pageHeight * pageWidth).toInt()
                pageHeight = MAX_SEWOO_BITMAP_SIZE
            }
            if (pageWidth > MAX_SEWOO_BITMAP_SIZE) {
                pageHeight = (MAX_SEWOO_BITMAP_SIZE.toDouble() / pageWidth * pageHeight).toInt()
                pageWidth = MAX_SEWOO_BITMAP_SIZE
            }

            val renderedBitmap = Bitmap.createBitmap(pageWidth, pageHeight, Bitmap.Config.ARGB_8888)
            renderedBitmap.eraseColor(Color.WHITE)
            page.render(renderedBitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)

            val finalPaperWidth = paperSize
            val scaledHeight = (finalPaperWidth.toDouble() / renderedBitmap.width * renderedBitmap.height)
                .toInt()
                .coerceAtLeast(1)
            val printableBitmap = Bitmap.createScaledBitmap(
                renderedBitmap,
                finalPaperWidth,
                scaledHeight,
                true
            )

            val bitmapResult = printer.printBitmap(printableBitmap, alignment, finalPaperWidth)
            if (bitmapResult != ESCPOSConst.LK_SUCCESS) return false
            printer.lineFeed(feed)
            return true
        } finally {
            page.close()
            renderer.close()
            pdfDescriptor.close()
        }
    }

    private fun openPdfFile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val file = File(call.argument<String>("filePath").orEmpty())
            if (!file.exists() || !file.isFile) {
                result.success(false)
                return
            }
            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.provider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
            }
            startActivity(Intent.createChooser(intent, "Abrir etiqueta"))
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_PDF_ERROR", e.message ?: "No fue posible abrir PDF", null)
        }
    }

    private class PdfFilePrintAdapter(private val file: File) : PrintDocumentAdapter() {
        override fun onLayout(
            oldAttributes: PrintAttributes?,
            newAttributes: PrintAttributes?,
            cancellationSignal: CancellationSignal?,
            callback: LayoutResultCallback?,
            extras: android.os.Bundle?
        ) {
            if (cancellationSignal?.isCanceled == true) {
                callback?.onLayoutCancelled()
                return
            }
            val info = PrintDocumentInfo.Builder(file.name)
                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                .setPageCount(PrintDocumentInfo.PAGE_COUNT_UNKNOWN)
                .build()
            callback?.onLayoutFinished(info, true)
        }

        override fun onWrite(
            pages: Array<out PageRange>?,
            destination: ParcelFileDescriptor?,
            cancellationSignal: CancellationSignal?,
            callback: WriteResultCallback?
        ) {
            try {
                if (cancellationSignal?.isCanceled == true) {
                    callback?.onWriteCancelled()
                    return
                }
                if (destination == null) {
                    callback?.onWriteFailed("Destino de impresion no disponible")
                    return
                }
                FileInputStream(file).use { input ->
                    FileOutputStream(destination.fileDescriptor).use { output ->
                        input.copyTo(output)
                    }
                }
                callback?.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
            } catch (e: Exception) {
                callback?.onWriteFailed(e.message)
            }
        }
    }

    companion object {
        private const val REQUEST_PACKAGE_PHOTO = 4011
        private const val PERMISSION_REQUEST_CAMERA = 4012
        private const val PERMISSION_REQUEST_BLUETOOTH_PRINT = 4013
        private const val TAG = "ControllerNative"
        private const val PHOTO_MAX_DIMENSION = 480
        private const val PHOTO_JPEG_QUALITY = 35
        private const val PHOTO_MAX_BASE64_LENGTH = 45 * 1024
        private const val MIN_IMAGE_DIMENSION = 220
        private const val IMAGE_DIMENSION_STEP = 0.82f
        private const val MIN_JPEG_QUALITY = 8
        private const val MAX_JPEG_QUALITY = 100
        private const val JPEG_QUALITY_STEP = 7
        private const val MAX_SEWOO_BITMAP_SIZE = 8200
    }

    private enum class SewooConnectMode {
        DEFAULT,
        INSECURE,
        SECURE
    }
}
