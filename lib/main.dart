import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/onboarding_provider.dart';
import 'services/scheduler/workmanager_scheduler.dart';

/// Entry point for Trail.
///
/// We intentionally keep `main` thin: initialise the WorkManager dispatcher
/// (which registers the background callback with the native WorkManager
/// plugin), load the "onboarding complete" flag into the Riverpod store
/// synchronously so the router can read it in its redirect rule, then hand
/// off to [TrailApp].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WorkmanagerScheduler.initialize();
  final onboarded = await OnboardingGate.isComplete();
  runApp(
    ProviderScope(
      overrides: [
        onboardingCompleteProvider.overrideWith((_) => onboarded),
      ],
      child: const TrailApp(),
    ),
  );
}
