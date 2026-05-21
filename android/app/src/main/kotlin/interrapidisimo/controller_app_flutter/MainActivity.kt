package interrapidisimo.controller_app_flutter

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.os.Build
import android.provider.Settings
import android.provider.MediaStore
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private var pendingPhotoResult: MethodChannel.Result? = null

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
                "compressImageBase64ToJpeg" -> compressImageBase64ToJpeg(call, result)
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PACKAGE_PHOTO) return
        val pending = pendingPhotoResult ?: return
        pendingPhotoResult = null
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
        pending.success(
            bitmapToJpegBase64(
                bitmap,
                PHOTO_MAX_DIMENSION,
                PHOTO_JPEG_QUALITY
            )
        )
    }

    private fun takePackagePhoto(result: MethodChannel.Result) {
        if (pendingPhotoResult != null) {
            result.error("CAMERA_BUSY", "Ya hay una captura en proceso.", null)
            return
        }
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        if (intent.resolveActivity(packageManager) == null) {
            result.success("")
            return
        }
        pendingPhotoResult = result
        startActivityForResult(intent, REQUEST_PACKAGE_PHOTO)
    }

    private fun compressImageBase64ToJpeg(call: MethodCall, result: MethodChannel.Result) {
        val imageBase64 = call.argument<String>("imageBase64").orEmpty()
        if (imageBase64.isBlank()) {
            result.success("")
            return
        }
        try {
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
                    call.argument<Int>("quality") ?: PHOTO_JPEG_QUALITY
                )
            )
        } catch (_: IllegalArgumentException) {
            result.success("")
        }
    }

    private fun bitmapToJpegBase64(bitmap: Bitmap, maxDimension: Int, quality: Int): String {
        val scaled = scaleBitmap(bitmap, maxDimension)
        val flattened = Bitmap.createBitmap(scaled.width, scaled.height, Bitmap.Config.RGB_565)
        Canvas(flattened).apply {
            drawColor(Color.WHITE)
            drawBitmap(scaled, 0f, 0f, null)
        }
        val output = ByteArrayOutputStream()
        flattened.compress(
            Bitmap.CompressFormat.JPEG,
            quality.coerceIn(MIN_JPEG_QUALITY, MAX_JPEG_QUALITY),
            output
        )
        if (scaled !== bitmap) {
            scaled.recycle()
        }
        flattened.recycle()
        return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
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
        private const val PHOTO_MAX_DIMENSION = 960
        private const val PHOTO_JPEG_QUALITY = 50
        private const val MIN_JPEG_QUALITY = 1
        private const val MAX_JPEG_QUALITY = 100
    }
}
