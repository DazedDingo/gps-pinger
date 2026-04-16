package com.dazeddingo.trail

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.CellInfo
import android.telephony.CellInfoCdma
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoWcdma
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Passive-only cell-tower + Wi-Fi SSID reads.
 *
 * Hard contract (PLAN.md "Battery budget"):
 * - No `WifiManager.startScan()`, no `requestCellInfoUpdate()`.
 * - Never register listeners.
 * - Read last-known state and return whatever is already cached.
 * - If a permission is missing or the radio is off, return null — the
 *   Flutter side treats it as an optional field.
 */
object CellWifiPlugin {
    private const val CHANNEL = "com.dazeddingo.trail/cell_wifi"

    fun register(engine: FlutterEngine, context: Context) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCellId" -> result.success(getCellId(context))
                "getWifiSsid" -> result.success(getWifiSsid(context))
                else -> result.notImplemented()
            }
        }
    }

    private fun hasPermission(context: Context, perm: String): Boolean {
        return ContextCompat.checkSelfPermission(context, perm) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun getCellId(context: Context): String? {
        if (!hasPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)) {
            return null
        }
        if (!hasPermission(context, Manifest.permission.READ_PHONE_STATE)) {
            return null
        }
        return try {
            val tm = context.getSystemService(Context.TELEPHONY_SERVICE)
                as? TelephonyManager ?: return null
            // `allCellInfo` is last-known cached info — no radio wake.
            @Suppress("MissingPermission")
            val cells: List<CellInfo>? = tm.allCellInfo
            if (cells.isNullOrEmpty()) return null
            val registered = cells.firstOrNull { it.isRegistered } ?: cells.first()
            formatCell(registered)
        } catch (_: SecurityException) {
            null
        } catch (_: Throwable) {
            null
        }
    }

    private fun formatCell(info: CellInfo): String? {
        return when (info) {
            is CellInfoLte -> "LTE:${info.cellIdentity.ci}"
            is CellInfoGsm -> "GSM:${info.cellIdentity.cid}"
            is CellInfoWcdma -> "WCDMA:${info.cellIdentity.cid}"
            is CellInfoCdma -> "CDMA:${info.cellIdentity.basestationId}"
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    info is CellInfoNr
                ) {
                    "NR:${info.cellIdentity}"
                } else {
                    null
                }
            }
        }
    }

    private fun getWifiSsid(context: Context): String? {
        if (!hasPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)) {
            return null
        }
        return try {
            val wm = context.applicationContext
                .getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return null
            // `connectionInfo` is cached — no scan triggered.
            @Suppress("DEPRECATION")
            val info = wm.connectionInfo ?: return null
            val ssid = info.ssid ?: return null
            // AOSP returns `<unknown ssid>` when permission is missing even
            // though we checked above — treat as null.
            if (ssid == "<unknown ssid>" || ssid.isEmpty()) return null
            ssid.trim('"').takeIf { it.isNotEmpty() }
        } catch (_: SecurityException) {
            null
        } catch (_: Throwable) {
            null
        }
    }
}
