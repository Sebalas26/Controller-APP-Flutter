package interrapidisimo.controller_app_flutter

import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
                else -> result.notImplemented()
            }
        }
    }
}
