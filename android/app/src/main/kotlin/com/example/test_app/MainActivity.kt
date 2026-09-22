package com.example.test_app

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "attendance/wifi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                when (call.method) {
                    // Registers the office network so Android auto-connects to it
                    // whenever it is in range, even when this app is not running.
                    "addSuggestion" -> {
                        val ssid = call.argument<String>("ssid")
                        val password = call.argument<String>("password")
                        if (ssid.isNullOrEmpty()) {
                            result.error("bad_args", "SSID is required", null)
                            return@setMethodCallHandler
                        }
                        // Replace any earlier suggestion so only the current office network remains.
                        wifi.removeNetworkSuggestions(emptyList())
                        val status = wifi.addNetworkSuggestions(
                            buildSuggestions(ssid, password, wifi.isWpa3SaeSupported)
                        )
                        result.success(status == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS)
                    }
                    // Android hides the Wi-Fi name while location is off.
                    "openLocationSettings" -> {
                        startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // A network is suggested as WPA2 and, where the phone supports it, WPA3 so it
    // matches either router setup. An empty password means an open network.
    private fun buildSuggestions(
        ssid: String,
        password: String?,
        wpa3Supported: Boolean,
    ): List<WifiNetworkSuggestion> {
        if (password.isNullOrEmpty()) {
            return listOf(WifiNetworkSuggestion.Builder().setSsid(ssid).build())
        }
        val suggestions = mutableListOf(
            WifiNetworkSuggestion.Builder().setSsid(ssid).setWpa2Passphrase(password).build()
        )
        if (wpa3Supported) {
            suggestions += WifiNetworkSuggestion.Builder().setSsid(ssid).setWpa3Passphrase(password).build()
        }
        return suggestions
    }
}
