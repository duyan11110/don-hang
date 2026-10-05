import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// lesson: frontend.l3.brand-themes
// A brand can change every color only while no screen or component writes
// one itself. This reads every Dart file under lib/ (flutter test runs in
// DonHang.App/) and fails on `Colors.` or `Color(` outside brand.dart, the
// one file whose job is to hold the brand's color values.
final rawColor = RegExp(r'\bColors\.|\bColor\(');

void main() {
  test('only brand.dart writes a color', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || path == 'lib/design/brand.dart') continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (rawColor.hasMatch(lines[i])) offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'use a theme role or a StatusColors value instead');
  });
}
