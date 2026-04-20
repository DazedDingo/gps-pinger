import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/onboarding_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/permissions_service.dart';
import '../../services/scheduler/workmanager_scheduler.dart';

/// 7-step onboarding, one PageView page per step.
///
/// Ordering is load-bearing (fine-location must precede background-location
/// on Android 11+). The contacts and home-location steps are informational
/// pointers: emergency contacts ship in the full Settings → Emergency
/// contacts screen (shipped in 0.2.0+11 alongside panic), and home location
/// is still pending (Phase 6).
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _controller = PageController();
  final _perms = PermissionsService();
  final _biometric = BiometricService();
  int _index = 0;

  void _next() {
    if (_index == 6) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    // Kick off the periodic worker immediately — even if permissions were
    // skipped, WorkManager still fires and will log `no_fix` rows (which is
    // what we want: user-visible proof the pipeline works).
    await WorkmanagerScheduler.enqueuePeriodic();
    await OnboardingGate.markComplete();
    ref.read(onboardingCompleteProvider.notifier).state = true;
    if (mounted) context.go('/lock');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  const _IntroStep(),
                  _FineLocationStep(perms: _perms),
                  _BackgroundLocationStep(perms: _perms),
                  _BatteryStep(perms: _perms),
                  const _ContactsStubStep(),
                  const _HomeLocationStubStep(),
                  _BiometricStep(biometric: _biometric),
                ],
              ),
            ),
            _StepIndicator(index: _index, total: 7),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_index > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_index == 6 ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int index;
  final int total;
  const _StepIndicator({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == index;
        return Container(
          width: active ? 16 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const _StepScaffold({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep();
  @override
  Widget build(BuildContext context) {
    return const _StepScaffold(
      icon: Icons.explore_outlined,
      title: 'Welcome to Trail',
      body:
          'Trail quietly logs your location every 4 hours so you always have '
          'a record of where you\'ve been — no cloud, no account, fully '
          'offline. This setup walks through the permissions it needs.',
    );
  }
}

class _FineLocationStep extends StatelessWidget {
  final PermissionsService perms;
  const _FineLocationStep({required this.perms});
  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.location_on_outlined,
      title: 'Location access',
      body:
          'Trail needs precise location to log GPS fixes. This prompt is the '
          'standard Android permission — you\'ll get another for background '
          'access next.',
      action: FilledButton(
        onPressed: () => perms.requestFineLocation(),
        child: const Text('Grant location'),
      ),
    );
  }
}

class _BackgroundLocationStep extends StatelessWidget {
  final PermissionsService perms;
  const _BackgroundLocationStep({required this.perms});
  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.my_location,
      title: 'Background location',
      body:
          'For scheduled pings every 4 hours, Android needs "Allow all the '
          'time". On the next dialog pick that option — otherwise pings will '
          'only happen when Trail is open.',
      action: FilledButton(
        onPressed: () => perms.requestBackgroundLocation(),
        child: const Text('Enable background'),
      ),
    );
  }
}

class _BatteryStep extends StatelessWidget {
  final PermissionsService perms;
  const _BatteryStep({required this.perms});
  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.battery_charging_full,
      title: 'Battery & alarms',
      body:
          'Some phones aggressively kill background work to save battery. '
          'Allow Trail to ignore battery optimisation so the 4h cadence '
          'holds.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(
            onPressed: () => perms.requestIgnoreBatteryOptimizations(),
            child: const Text('Ignore battery optimisation'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => perms.requestNotifications(),
            child: const Text('Also allow notifications'),
          ),
        ],
      ),
    );
  }
}

class _ContactsStubStep extends StatelessWidget {
  const _ContactsStubStep();
  @override
  Widget build(BuildContext context) {
    return const _StepScaffold(
      icon: Icons.contacts_outlined,
      title: 'Emergency contacts (optional)',
      body:
          'If you hit the panic button on the home screen, Trail can pre-fill '
          'an SMS to people you trust with your last known location. Skip for '
          'now — once setup finishes, open Settings → Emergency contacts to '
          'add them.',
    );
  }
}

class _HomeLocationStubStep extends StatelessWidget {
  const _HomeLocationStubStep();
  @override
  Widget build(BuildContext context) {
    return const _StepScaffold(
      icon: Icons.home_outlined,
      title: 'Home location (optional)',
      body:
          'Setting a home location enables future features like "home '
          'radius" alerts. Skip for now — you can set it in Settings later.',
    );
  }
}

class _BiometricStep extends StatefulWidget {
  final BiometricService biometric;
  const _BiometricStep({required this.biometric});

  @override
  State<_BiometricStep> createState() => _BiometricStepState();
}

class _BiometricStepState extends State<_BiometricStep> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.fingerprint,
      title: 'Biometric lock',
      body:
          'Trail locks behind your fingerprint/face each time you open it. '
          'If no biometric is enrolled, it falls back to your device PIN.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(
            onPressed: () async {
              final avail = await widget.biometric.isAvailable();
              if (!avail) {
                setState(() => _status =
                    'No biometric available — device PIN will be used.');
                return;
              }
              final ok = await widget.biometric.authenticate(
                reason: 'Verify biometric for Trail',
              );
              setState(() => _status = ok ? 'Verified.' : 'Not verified.');
            },
            child: const Text('Test biometric'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!),
          ],
        ],
      ),
    );
  }
}
