import 'package:flutter/material.dart';

import '../status_colors.dart';
import '../tokens.dart';

/// What a [StatusBanner] means; the banner picks its colors from it.
enum StatusTone { info, success, warning, error }

// lesson: frontend.l3.component-gallery
// lesson: frontend.l3.component-library
/// A short message about the state of something on the screen, colored by
/// what it means, with at most one action.
///
/// Use it for something the customer should notice next to the rest of the
/// screen: a saved list that may be out of date, an order waiting to be sent,
/// an error from the server. Not for a screen with nothing else to show: use
/// [MessageView]. It takes a [tone], never a color, so every banner of the
/// same tone looks the same and changes with the theme.
class StatusBanner extends StatelessWidget {
  final String message;
  final StatusTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StatusBanner({super.key, required this.message, required this.tone, this.actionLabel, this.onAction});

  // lesson: frontend.l3.component-library
  // The background and the text color for each tone, both from the theme:
  // ColorScheme's roles where Material has one, StatusColors where not.
  (Color, Color) _colors(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<StatusColors>()!;
    return switch (tone) {
      StatusTone.info => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      StatusTone.success => (status.success, status.onSuccess),
      StatusTone.warning => (status.warning, status.onWarning),
      StatusTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors(context);
    final label = actionLabel;
    return Material(
      color: background,
      child: Padding(
        padding: Insets.tile,
        child: Row(
          children: [
            Expanded(
              child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground)),
            ),
            if (label != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(label),
              ),
          ],
        ),
      ),
    );
  }
}
