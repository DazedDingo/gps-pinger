import 'package:flutter/material.dart';

/// One row in a [HelpButton] dialog: an icon, a short title, and a
/// plain-English body explaining what an action / control / concept on
/// this screen does. Keep bodies non-jargon so the dialog reads as a
/// user manual, not a developer note.
class HelpSection {
  final IconData icon;
  final String title;
  final String body;
  const HelpSection({
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// `?` icon button for the AppBar. Tapping pops a "How to use:
/// {screenTitle}" dialog with the supplied [HelpSection]s rendered as
/// icon + title + body rows. Mirrors the groceries-app HelpButton so
/// the experience reads the same across the user's Flutter apps.
class HelpButton extends StatelessWidget {
  final String screenTitle;
  final List<HelpSection> sections;

  const HelpButton({
    super.key,
    required this.screenTitle,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'How to use',
      onPressed: () => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('How to use: $screenTitle'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: sections
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                s.icon,
                                size: 20,
                                color:
                                    Theme.of(ctx).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.title,
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight:
                                                  FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.body,
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
