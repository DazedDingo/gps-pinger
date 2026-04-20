package com.dazeddingo.trail

import android.content.Context

/**
 * Tiny SharedPreferences wrapper for panic configuration that both the
 * Flutter side (via [PanicMethodChannel]) and the Phase 3 quick-tile /
 * widget entry points need to read.
 *
 * The Flutter-side source-of-truth is still
 * `panicDurationProvider` + `flutter_secure_storage` — this is a
 * native-readable mirror, not the primary store. Every change on the
 * Dart side mirrors here via `setContinuousDurationMinutes`, and native
 * readers (tile service, widget provider) fall back to the default when
 * the mirror is empty (first run, pre-mirror installs).
 */
object PanicPrefs {
    private const val FILE = "trail_panic_prefs"
    private const val KEY_DURATION_MINUTES = "duration_minutes"
    const val DEFAULT_DURATION_MINUTES = 30

    fun setDurationMinutes(context: Context, minutes: Int) {
        val clamped = minutes.coerceIn(1, 120)
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY_DURATION_MINUTES, clamped)
            .apply()
    }

    fun getDurationMinutes(context: Context): Int {
        return context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getInt(KEY_DURATION_MINUTES, DEFAULT_DURATION_MINUTES)
    }
}
