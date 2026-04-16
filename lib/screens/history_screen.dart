import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/ping.dart';
import '../providers/pings_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentPingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: recent.when(
        data: (pings) {
          if (pings.isEmpty) {
            return const Center(child: Text('No pings yet.'));
          }
          return ListView.separated(
            itemCount: pings.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _HistoryTile(ping: pings[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed: $e')),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Ping ping;
  const _HistoryTile({required this.ping});

  @override
  Widget build(BuildContext context) {
    final ts = DateFormat.yMMMd().add_Hms().format(ping.timestampUtc.toLocal());
    return ListTile(
      title: Text(
        ping.lat != null && ping.lon != null
            ? '${ping.lat!.toStringAsFixed(5)}, ${ping.lon!.toStringAsFixed(5)}'
            : (ping.note ?? ping.source.dbValue),
      ),
      subtitle: Text(
        '$ts  ·  ${ping.source.dbValue}'
        '${ping.batteryPct != null ? "  ·  batt ${ping.batteryPct}%" : ""}'
        '${ping.networkState != null ? "  ·  ${ping.networkState}" : ""}',
      ),
    );
  }
}
