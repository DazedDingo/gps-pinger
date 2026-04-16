package com.dazeddingo.trail

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Standard Flutter host activity. Registers the `com.dazeddingo.trail/cell_wifi`
 * MethodChannel so Flutter can pull passive cell-tower + Wi-Fi info from the
 * native side without triggering active scans (see PLAN.md battery rules).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CellWifiPlugin.register(flutterEngine, applicationContext)
    }
}
