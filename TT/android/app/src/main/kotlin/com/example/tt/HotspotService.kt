package com.example.tt

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.util.Log

/**
 * Controls the guide's local-only Wi-Fi hotspot and lets members join it.
 *
 * The hotspot shares no internet connection; it only puts every device on the
 * same LAN so they can exchange live locations when the internet is down.
 */
class HotspotService(private val context: Context) {
    private val TAG = "HotspotService"

    private val wifiManager: WifiManager? =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    fun hasInternet(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val caps = connectivityManager.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    /**
     * Starts a local-only hotspot and returns its SSID + password, or null when
     * the platform/device does not support it.
     */
    @Suppress("DEPRECATION")
    fun startHotspot(): Map<String, String>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.w(TAG, "Local-only hotspot requires API 26+")
            return null
        }
        if (reservation != null) {
            return readCredentials(reservation!!)
        }
        val manager = wifiManager ?: return null

        // startLocalOnlyHotspot is async; block briefly until the config arrives.
        val latch = java.util.concurrent.CountDownLatch(1)
        var result: Map<String, String>? = null
        var error: String? = null

        manager.startLocalOnlyHotspot(
            object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                    reservation = res
                    result = readCredentials(res)
                    latch.countDown()
                }

                override fun onStopped() {
                    error = "Hotspot stopped"
                    latch.countDown()
                }

                override fun onFailed(reason: Int) {
                    error = "Hotspot failed with reason $reason"
                    latch.countDown()
                }
            },
            null
        )

        latch.await(10, java.util.concurrent.TimeUnit.SECONDS)
        if (result == null) {
            Log.w(TAG, "Could not start hotspot: $error")
        }
        return result
    }

    @Suppress("DEPRECATION")
    private fun readCredentials(res: WifiManager.LocalOnlyHotspotReservation): Map<String, String>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val config = res.softApConfiguration
            val ssid = config.ssid ?: return null
            val password = config.passphrase ?: ""
            mapOf("ssid" to ssid, "password" to password)
        } else {
            val config = res.wifiConfiguration ?: return null
            val ssid = config.SSID ?: return null
            val password = config.preSharedKey ?: ""
            mapOf("ssid" to ssid, "password" to password)
        }
    }

    fun stopHotspot() {
        try {
            reservation?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping hotspot", e)
        }
        reservation = null
    }

    /**
     * Joins the guide's hotspot. On Android 10+ this shows a system dialog the
     * user must accept.
     */
    fun connectToHotspot(ssid: String, password: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            Log.w(TAG, "Programmatic Wi-Fi join requires API 29+")
            return false
        }
        disconnectHotspot()

        val specifierBuilder = WifiNetworkSpecifier.Builder().setSsid(ssid)
        if (password.isNotEmpty()) {
            specifierBuilder.setWpa2Passphrase(password)
        }
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifierBuilder.build())
            .build()

        val latch = java.util.concurrent.CountDownLatch(1)
        var connected = false

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                connectivityManager.bindProcessToNetwork(network)
                connected = true
                latch.countDown()
            }

            override fun onUnavailable() {
                connected = false
                latch.countDown()
            }
        }
        networkCallback = callback

        connectivityManager.requestNetwork(request, callback)
        latch.await(30, java.util.concurrent.TimeUnit.SECONDS)
        if (!connected) {
            disconnectHotspot()
        }
        return connected
    }

    fun disconnectHotspot() {
        networkCallback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } catch (e: Exception) {
                Log.w(TAG, "unregisterNetworkCallback failed", e)
            }
        }
        networkCallback = null
        connectivityManager.bindProcessToNetwork(null)
    }

    fun stopAll() {
        stopHotspot()
        disconnectHotspot()
    }
}
