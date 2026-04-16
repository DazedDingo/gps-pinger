package com.dazeddingo.trail

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import be.tramckrijte.workmanager.BackgroundWorker

/**
 * Fires on BOOT_COMPLETED (and MY_PACKAGE_REPLACED so upgrades also re-arm).
 *
 * Enqueues a one-off WorkManager task that runs the Flutter
 * `trail_boot_ping` callback, which inside Dart:
 *   1. Inserts a `boot` marker row into the encrypted DB.
 *   2. Triggers an immediate GPS fix attempt (doesn't wait for the next
 *      scheduled window).
 *   3. Re-enqueues the 4h periodic worker.
 *
 * This uses the workmanager plugin's own [BackgroundWorker] class so the
 * task re-enters the Flutter isolate with the right dispatcher wiring.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val inputData = androidx.work.Data.Builder()
            .putString(DART_TASK_KEY, BOOT_TASK_NAME)
            .putBoolean(IS_IN_DEBUG_MODE_KEY, false)
            .build()

        val request = OneTimeWorkRequestBuilder<BackgroundWorker>()
            .setInputData(inputData)
            .addTag(TAG_BOOT)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            UNIQUE_NAME,
            ExistingWorkPolicy.KEEP,
            request,
        )
    }

    companion object {
        // Must match the taskName used in Dart (`WorkmanagerScheduler.bootTaskName`).
        private const val BOOT_TASK_NAME = "trail_boot_ping"
        private const val TAG_BOOT = "trail:boot"
        private const val UNIQUE_NAME = "trail_boot_ping_unique"

        // Keys the workmanager plugin's BackgroundWorker reads out of
        // WorkRequest input data. Stable public contract of the plugin
        // (see workmanager/android/src/main/kotlin/.../BackgroundWorker.kt).
        private const val DART_TASK_KEY = "be.tramckrijte.workmanager.DART_TASK"
        private const val IS_IN_DEBUG_MODE_KEY = "be.tramckrijte.workmanager.IS_IN_DEBUG_MODE_KEY"
    }
}
