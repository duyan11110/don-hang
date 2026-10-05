import 'package:flutter/material.dart';

import '../tokens.dart';

/// What a whole screen shows instead of its data: one centered message, such
/// as "No products yet." or a load error, and at most one action.
///
/// Use it when the screen has nothing else to show. When there is data to
/// show next to the message, such as a saved list, use [StatusBanner] above
/// the data instead.
class MessageView extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MessageView({super.key, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Center(
      child: Padding(
        padding: Insets.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (label != null) ...[
              const SizedBox(height: Space.sm),
              TextButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
