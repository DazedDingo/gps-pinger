package com.dazeddingo.trail

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker

/**
 * Receives the exact alarm fired by [ExactAlarmScheduler] and does two
 * things in order:
 *   1. Enqueues a one-off WorkManager task that re-enters the Flutter
 *      isolate via [BackgroundWorker] and runs
 *      `_handleScheduled` in `workmanager_scheduler.dart` — the same DB
 *      + GPS path the periodic WorkManager job uses.
 *   2. Schedules the next exact alarm 4h out so the cadence continues.
 *
 * Order matters: we schedule the next alarm AFTER enqueueing the
 * current ping, so if step 1 throws (OOM, WorkManager dead) we don't
 * lose the cadence. If step 2 throws we at least got this ping done.
 *
 * The dispatching-to-Flutter pattern mirrors [BootReceiver] — same
 * [DART_TASK_KEY] the workmanager plugin reads, same
 * [BackgroundWorker] type.
 */
class ExactAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ExactAlarmScheduler.ACTION_SCHEDULED_PING) return

        SchedulerEventsLog.record(
            context,
            SchedulerEventsLog.EventKind.EXACT_FIRED,
        )

        enqueueScheduledPing(context)
        ExactAlarmScheduler.scheduleNext(context)
    }

    private fun enqueueScheduledPing(context: Context) {
        try {
            val inputData = Data.Builder()
                .putString(DART_TASK_KEY, SCHEDULED_TASK_NAME)
                .build()
            val request = OneTimeWorkRequestBuilder<BackgroundWorker>()
                .setInputData(inputData)
                .addTag(TAG_SCHEDULED)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                "trail_exact_scheduled_${System.currentTimeMillis()}",
                ExistingWorkPolicy.APPEND,
                request,
            )
            SchedulerEventsLog.record(
                context,
                SchedulerEventsLog.EventKind.WORKMANAGER_ENQUEUED,
                note = "exact→flutter",
            )
        } catch (t: Throwable) {
            SchedulerEventsLog.record(
                context,
                SchedulerEventsLog.EventKind.EXACT_FIRED,
                note = "enqueue failed: ${t.message}",
            )
        }
    }

    companion object {
        // Must match WorkmanagerScheduler.periodicTaskName on the Dart side.
        private const val SCHEDULED_TASK_NAME = "trail_scheduled_ping"
        private const val TAG_SCHEDULED = "trail:scheduled"
        // Stable contract with the workmanager plugin (same key BootReceiver uses).
        private const val DART_TASK_KEY = "dev.fluttercommunity.workmanager.DART_TASK"
    }
}
