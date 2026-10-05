import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/design/brand.dart';
import 'package:donhang_app/design/components/status_banner.dart';
import 'package:donhang_app/design/status_colors.dart';
import 'package:donhang_app/design/theme.dart';

// lesson: frontend.l3.brand-themes
// A second brand, for this test only: another seed and other status colors.
// The components must take their colors from whichever brand built the theme.
const testBrand = Brand(
  seed: Colors.teal,
  lightStatus: StatusColors(
    warning: Color(0xFF8A3D00),
    onWarning: Color(0xFFFFFFFF),
    success: Color(0xFF00658A),
    onSuccess: Color(0xFFFFFFFF),
  ),
  darkStatus: StatusColors(
    warning: Color(0xFFFFB68A),
    onWarning: Color(0xFF4A1F00),
    success: Color(0xFF8ACFFF),
    onSuccess: Color(0xFF00344A),
  ),
);

Color backgroundOf(WidgetTester tester) => tester
    .widget<Material>(find.descendant(of: find.byType(StatusBanner), matching: find.byType(Material)).first)
    .color!;

void main() {
  for (final brightness in Brightness.values) {
    // lesson: frontend.l3.brand-themes
    testWidgets('components follow the test brand (${brightness.name})', (tester) async {
      final theme = buildTheme(testBrand, brightness);
      final scheme = ColorScheme.fromSeed(seedColor: testBrand.seed, brightness: brightness);

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const Scaffold(body: StatusBanner(message: 'Info.', tone: StatusTone.info)),
      ));
      expect(backgroundOf(tester), scheme.secondaryContainer);

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const Scaffold(body: StatusBanner(message: 'Warning.', tone: StatusTone.warning)),
      ));
      expect(backgroundOf(tester), testBrand.statusColors(brightness).warning);
    });
  }

  // Otherwise the test above would pass even if the brand were ignored.
  test('the two brands really differ', () {
    final ours = buildTheme(donHangBrand, Brightness.light).colorScheme.secondaryContainer;
    final test = buildTheme(testBrand, Brightness.light).colorScheme.secondaryContainer;
    expect(ours, isNot(test));
  });
}
