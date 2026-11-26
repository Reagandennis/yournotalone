package com.techgetafrica.yournotalone

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Extends AudioServiceFragmentActivity so a sound keeps playing with the
// screen locked and the lock-screen controls work, and so the Health Connect
// permission dialog (the health plugin's registerForActivityResult, which
// needs a FragmentActivity) can open at all.
class MainActivity : AudioServiceFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // One small channel: when notifications have been refused, the app
        // can send people straight to this app's notification settings
        // instead of describing the path through Settings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yournotalone/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSettings" -> {
                        openNotificationSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Which country the SIM card and the mobile network are from, for
        // session prices when the Play account's country isn't known. Needs
        // no permission, and nothing else about the phone is read.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yournotalone/telephony")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "countries" -> result.success(telephonyCountries())
                    else -> result.notImplemented()
                }
            }
    }

    private fun telephonyCountries(): Map<String, String?> {
        fun code(value: String?) = value?.trim()?.uppercase()?.takeIf { it.length == 2 }
        return try {
            val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            mapOf("sim" to code(telephony?.simCountryIso), "network" to code(telephony?.networkCountryIso))
        } catch (e: Exception) {
            // A tablet without a SIM, or a phone that won't say.
            mapOf("sim" to null, "network" to null)
        }
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // Fall back to the app's details page, which every Android has.
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
