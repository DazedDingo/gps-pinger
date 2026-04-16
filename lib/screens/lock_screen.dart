import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/biometric_service.dart';
import '../services/scheduler/workmanager_scheduler.dart';

/// Biometric gate shown on every app launch + resume from background.
///
/// Kept intentionally minimal: a lock icon, an "Unlock" button that triggers
/// [BiometricService.authenticate], and an auto-trigger on first build so
/// the user doesn't have to tap twice in the happy path.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _biometric = BiometricService();
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAuth());
  }

  Future<void> _tryAuth() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    final ok = await _biometric.authenticate();
    if (!mounted) return;
    if (ok) {
      // Opportunistically top up the periodic worker each unlock — this
      // costs nothing if it's already enqueued, and recovers if the user
      // force-stopped the app.
      await WorkmanagerScheduler.enqueuePeriodic();
      if (!mounted) return;
      context.go('/home');
    } else {
      setState(() {
        _authenticating = false;
        _error = 'Authentication failed. Tap to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 72),
              const SizedBox(height: 16),
              Text('Trail', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _authenticating ? null : _tryAuth,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
