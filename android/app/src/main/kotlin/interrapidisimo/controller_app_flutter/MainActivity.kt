package interrapidisimo.controller_app_flutter

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.os.Build
import android.provider.Settings
import android.provider.MediaStore
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.zxing.integration.android.IntentIntegrator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private var pendingPhotoResult: MethodChannel.Result? = null
    private var pendingQrResult: MethodChannel.Result? = null

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
                "getAesKeySecret" -> result.success("SW50M3JyNHAxZDFzMW0wQ2w0UzMzbmNyMXBjMTBuUHQyMDIy")
                "getAesSaltSecret" -> result.success("MW5UM3JyNHAxZDFTMU0wXzIwMjI=")
                "takePackagePhoto" -> takePackagePhoto(result)
                "scanQrCode" -> scanQrCode(result)
                "compressImageBase64ToJpeg" -> compressImageBase64ToJpeg(call, result)
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

    companion object {
        private const val REQUEST_PACKAGE_PHOTO = 4011
        private const val PERMISSION_REQUEST_CAMERA = 4012
        private const val PHOTO_MAX_DIMENSION = 480
        private const val PHOTO_JPEG_QUALITY = 35
        private const val PHOTO_MAX_BASE64_LENGTH = 45 * 1024
        private const val MIN_IMAGE_DIMENSION = 220
        private const val IMAGE_DIMENSION_STEP = 0.82f
        private const val MIN_JPEG_QUALITY = 8
        private const val MAX_JPEG_QUALITY = 100
        private const val JPEG_QUALITY_STEP = 7
    }
}

