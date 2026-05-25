package com.example.cryptasafe

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.cryptasafe/sms_wipe"
    private val SMS_PERMISSION_CODE = 101

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    // Block screenshots and screen recording inside the app
    window.setFlags(
        android.view.WindowManager.LayoutParams.FLAG_SECURE,
        android.view.WindowManager.LayoutParams.FLAG_SECURE
    )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "checkWipeFlag" -> {
                    // Check if SMS wipe was triggered while app was closed
                    val prefs = getSharedPreferences(
                        SmsWipeReceiver.PREFS_NAME,
                        MODE_PRIVATE
                    )
                    val wipeTriggered = prefs.getBoolean(
                        SmsWipeReceiver.WIPE_TRIGGERED_KEY,
                        false
                    )
                    // Clear the flag after reading
                    if (wipeTriggered) {
                        prefs.edit()
                            .remove(SmsWipeReceiver.WIPE_TRIGGERED_KEY)
                            .apply()
                    }
                    result.success(wipeTriggered)
                }

                "hasSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }

                "requestSmsPermission" -> {
                    if (ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECEIVE_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                Manifest.permission.RECEIVE_SMS,
                                Manifest.permission.READ_SMS
                            ),
                            SMS_PERMISSION_CODE
                        )
                        // Will return after permission dialog
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
