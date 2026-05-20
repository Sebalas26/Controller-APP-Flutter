package interrapidisimo.controller_app_flutter

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.provider.Settings
import android.provider.MediaStore
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

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
        val bitmap = data?.extras?.get("data") as? Bitmap
        if (bitmap == null) {
            pending.success("")
            return
        }
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, output)
        pending.success(Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP))
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

    companion object {
        private const val REQUEST_PACKAGE_PHOTO = 4011
    }
}
