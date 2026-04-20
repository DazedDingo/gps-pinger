package com.dazeddingo.trail

import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * Quick-settings tile entry point for continuous-panic.
 *
 * Tapping the tile:
 *   - Reads the user's last-chosen duration from [PanicPrefs] (falls
 *     back to 30 min if the mirror is empty — e.g. pre-0.3 install).
 *   - Starts [PanicForegroundService] directly. That service posts the
 *     ongoing "Panic active" notification and handles the timer loop,
 *     so the tile returns immediately and the user can panic without
 *     ever opening the app.
 *
 * We intentionally *don't* try to reflect the running-state back on the
 * tile (no `updateTile`-on-service-state wiring). The FG service already
 * owns a prominent notification with its own Stop action; mirroring to
 * the tile adds surface area without user value for an emergency flow.
 *
 * minSdk for QS tiles is API 24 (Android 7.0).
 */
@RequiresApi(Build.VERSION_CODES.N)
class PanicTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        tile.state = Tile.STATE_INACTIVE
        tile.label = "Panic"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = "${PanicPrefs.getDurationMinutes(this)} min"
        }
        tile.icon = Icon.createWithResource(this, android.R.drawable.ic_menu_mylocation)
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        val minutes = PanicPrefs.getDurationMinutes(this)
        PanicForegroundService.start(applicationContext, minutes)
        // Flash ACTIVE briefly for user feedback; the tile goes back to
        // INACTIVE on the next listen cycle.
        qsTile?.let {
            it.state = Tile.STATE_ACTIVE
            it.updateTile()
        }
    }
}
