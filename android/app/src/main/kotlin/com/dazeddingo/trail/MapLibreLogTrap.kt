package com.dazeddingo.trail

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.maplibre.android.log.Logger
import org.maplibre.android.log.LoggerDefinition

/**
 * Captures everything maplibre-native logs through its `Logger` API
 * into a process-local ring buffer so the Flutter side can inspect it
 * without adb/logcat. Also forwards to Android's regular log system so
 * if the user *does* have logcat available it still works.
 *
 * Hooked from [MainActivity.configureFlutterEngine] before any
 * MapLibreMap is built. The ring buffer is small (last 200 entries —
 * tile-level errors fire ~once per failing tile, and we'd rather see
 * the most recent than the noisiest old ones).
 *
 * MethodChannel `com.dazeddingo.trail/maplibre_logs`:
 *   - `getRecent`: returns the ring buffer as `List<String>`
 *   - `clear`:     empties the buffer
 *
 * If this trap ever surfaces a recurring "expected gzipped tile,
 * got X" or "no source-layer named Y" we'll have our root cause and
 * can stop guessing at headers.
 */
object MapLibreLogTrap {
    private const val CHANNEL = "com.dazeddingo.trail/maplibre_logs"
    private const val MAX_ENTRIES = 200

    private val buffer = ArrayDeque<String>()
    private val lock = Any()

    fun register(flutterEngine: FlutterEngine) {
        installLogger()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRecent" -> result.success(snapshot())
                    "clear" -> {
                        synchronized(lock) { buffer.clear() }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun installLogger() {
        Logger.setLoggerDefinition(object : LoggerDefinition {
            override fun v(tag: String, msg: String) =
                record('V', tag, msg, null)

            override fun v(tag: String, msg: String, tr: Throwable?) =
                record('V', tag, msg, tr)

            override fun d(tag: String, msg: String) =
                record('D', tag, msg, null)

            override fun d(tag: String, msg: String, tr: Throwable?) =
                record('D', tag, msg, tr)

            override fun i(tag: String, msg: String) =
                record('I', tag, msg, null)

            override fun i(tag: String, msg: String, tr: Throwable?) =
                record('I', tag, msg, tr)

            override fun w(tag: String, msg: String) =
                record('W', tag, msg, null)

            override fun w(tag: String, msg: String, tr: Throwable?) =
                record('W', tag, msg, tr)

            override fun e(tag: String, msg: String) =
                record('E', tag, msg, null)

            override fun e(tag: String, msg: String, tr: Throwable?) =
                record('E', tag, msg, tr)
        })
    }

    private fun record(level: Char, tag: String, msg: String, tr: Throwable?) {
        val ts = System.currentTimeMillis()
        val trText = tr?.let {
            "\n  caused by: ${it::class.java.simpleName}: ${it.message ?: ""}"
        } ?: ""
        val line = "$ts $level/$tag: $msg$trText"
        synchronized(lock) {
            buffer.addLast(line)
            while (buffer.size > MAX_ENTRIES) buffer.removeFirst()
        }
        // Mirror to logcat so adb-equipped users still see the stream.
        when (level) {
            'V' -> android.util.Log.v(tag, msg, tr)
            'D' -> android.util.Log.d(tag, msg, tr)
            'I' -> android.util.Log.i(tag, msg, tr)
            'W' -> android.util.Log.w(tag, msg, tr)
            'E' -> android.util.Log.e(tag, msg, tr)
            else -> android.util.Log.i(tag, msg, tr)
        }
    }

    private fun snapshot(): List<String> = synchronized(lock) { buffer.toList() }
}
