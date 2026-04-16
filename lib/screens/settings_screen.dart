import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/permissions_service.dart';
import '../services/scheduler/workmanager_scheduler.dart';

/// Minimal settings for Phase 1 — deep links into system permission dialogs
/// and a re-enqueue action. The full diagnostics screen (worker history,
/// Doze state) is Phase 6.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = PermissionsService();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Location permissions'),
            subtitle: const Text('Open system settings to adjust'),
            onTap: perms.openSettings,
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver_outlined),
            title: const Text('Battery optimisation'),
            subtitle: const Text('Request ignore-battery-optimisation'),
            onTap: perms.requestIgnoreBatteryOptimizations,
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Re-enqueue 4h periodic worker'),
            subtitle: const Text(
              'Useful after force-stop or uninstall/reinstall',
            ),
            onTap: () async {
              await WorkmanagerScheduler.enqueuePeriodic();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Worker re-enqueued')),
                );
              }
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Trail'),
            subtitle: Text('Phase 1 MVP'),
          ),
        ],
      ),
    );
  }
}
