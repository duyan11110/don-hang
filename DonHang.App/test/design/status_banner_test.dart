import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/design/brand.dart';
import 'package:donhang_app/design/components/status_banner.dart';
import 'package:donhang_app/design/status_colors.dart';
import 'package:donhang_app/design/theme.dart';

// lesson: frontend.l3.component-library
// The theme's own role for each tone: what the banner's background must be.
Color expectedBackground(ThemeData theme, StatusTone tone) {
  final status = theme.extension<StatusColors>()!;
  return switch (tone) {
    StatusTone.info => theme.colorScheme.secondaryContainer,
    StatusTone.success => status.success,
    StatusTone.warning => status.warning,
    StatusTone.error => theme.colorScheme.errorContainer,
  };
}

void main() {
  final theme = buildTheme(donHangBrand, Brightness.light);

  // lesson: frontend.l3.component-library
  // One banner per tone: the screen passes a meaning, the banner finds the
  // colors, so its background is the theme's role for that tone.
  for (final tone in StatusTone.values) {
    testWidgets('a ${tone.name} banner takes its background from the theme', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: StatusBanner(message: 'Something happened.', tone: tone, actionLabel: 'Undo', onAction: () => tapped = true),
        ),
      ));

      expect(find.text('Something happened.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Undo'));
      expect(tapped, isTrue);
      final background = tester.widget<Material>(
        find.descendant(of: find.byType(StatusBanner), matching: find.byType(Material)).first,
      );
      expect(background.color, expectedBackground(theme, tone));
    });
  }

  testWidgets('without an action label there is no button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const Scaffold(body: StatusBanner(message: 'Waiting.', tone: StatusTone.info)),
    ));

    expect(find.byType(TextButton), findsNothing);
  });
}
