package com.dazeddingo.trail

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Rolling log of the last [MAX_EVENTS] scheduler events, persisted in a
 * native [android.content.SharedPreferences] file so both the exact-alarm
 * receiver (native) and the Flutter UI isolate (via MethodChannel) can
 * read/write it without crossing isolate boundaries.
 *
 * The log is the only observability surface for "did my exact alarm
 * actually fire at 4h?" — WorkManager's periodic job is a black box,
 * and Android has no user-facing way to inspect AlarmManager state.
 *
 * Storage layout: a single `events` key holding a JSON array. Each
 * entry is `{tsMs, kind, note?}`; newest first. `kind` is one of the
 * [EventKind] enum values, stored as its lowercase name.
 *
 * Intentionally append-only with a hard trim: we don't ever want a
 * runaway log bloating shared_prefs, and 20 entries (~1 week at 4h
 * cadence) is enough for "is it working right now" diagnostics without
 * turning into a forensic timeline.
 */
object SchedulerEventsLog {
    private const val TAG = "SchedEvents"
    private const val FILE = "trail_scheduler_events"
    private const val KEY = "events"
    const val MAX_EVENTS = 20

    enum class EventKind {
        EXACT_SCHEDULED,
        EXACT_FIRED,
        EXACT_CANCELLED,
        EXACT_PERMISSION_DENIED,
        MODE_CHANGED,
        WORKMANAGER_ENQUEUED;

        fun serialize(): String = name.lowercase()
    }

    fun record(context: Context, kind: EventKind, note: String? = null) {
        try {
            val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            val existing = prefs.getString(KEY, null)
            val arr = if (existing.isNullOrBlank()) JSONArray() else JSONArray(existing)

            val entry = JSONObject().apply {
                put("tsMs", System.currentTimeMillis())
                put("kind", kind.serialize())
                if (!note.isNullOrBlank()) put("note", note)
            }

            // Prepend (newest first) and trim.
            val trimmed = JSONArray()
            trimmed.put(entry)
            var copied = 1
            var i = 0
            while (i < arr.length() && copied < MAX_EVENTS) {
                trimmed.put(arr.get(i))
                copied++
                i++
            }

            prefs.edit().putString(KEY, trimmed.toString()).apply()
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to record $kind: ${t.message}")
        }
    }

    /**
     * Returns the raw JSON array string — cheaper than rebuilding on the
     * MethodChannel side. Dart parses it with `jsonDecode`.
     */
    fun readJson(context: Context): String {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        return prefs.getString(KEY, null) ?: "[]"
    }

    fun clear(context: Context) {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY).apply()
    }
}
