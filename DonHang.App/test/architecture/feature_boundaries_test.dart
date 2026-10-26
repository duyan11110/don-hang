import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// lesson: frontend.l4.feature-public-files
// Which features each feature may use. Ordering places orders for Catalog's
// products and signed-in customers; Catalog shows a sign-in button; Auth
// uses no feature. A feature missing from a list may not be imported, so
// no two features can come to depend on each other.
const allowed = {
  'ordering': {'catalog', 'auth'},
  'catalog': {'auth'},
  'auth': <String>{},
};

// The quoted URIs of one import or export line, a conditional one included:
// export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
final directive = RegExp(r"^\s*(?:import|export)\s+'([^']+)'(?:\s+if\s*\([^)]*\)\s*'([^']+)')?");

// lesson: frontend.l4.feature-public-files
// Reads the imports and exports of every Dart file under lib/ (flutter test
// runs in DonHang.App/), as no_raw_colors_test.dart reads its colors, and
// fails with the file, the line and the rule each one breaks.
void main() {
  test('features reach each other only through their public files', () {
    final offences = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final from = file.path.replaceAll(r'\', '/').substring('lib/'.length);
      if (!from.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = directive.firstMatch(lines[i]);
        if (match == null) continue;
        for (final uri in [match.group(1), match.group(2)].whereType<String>()) {
          final target = resolve(from, uri);
          if (target == null) continue;
          final problem = check(from, target);
          if (problem != null) offences.add('lib/$from:${i + 1}: ${lines[i].trim()} ($problem)');
        }
      }
    }
    expect(offences, isEmpty, reason: 'go through features/<feature>/<feature>.dart, in the allowed direction');
  });
}

// What the rules say about [from] using [target], both paths under lib/;
// null when it is allowed.
String? check(String from, String target) {
  final into = featureOf(target);
  if (into == null) return null;
  final owner = featureOf(from);
  if (owner == into) return null;
  if (from.startsWith('shared/') || from.startsWith('design/')) {
    return 'shared/ and design/ may not use a feature';
  }
  if (target != 'features/$into/$into.dart') {
    return 'only features/$into/$into.dart is public';
  }
  if (owner != null && !(allowed[owner] ?? const {}).contains(into)) {
    return '$owner may not use $into';
  }
  return null;
}

// The feature a path under lib/ belongs to, or null outside features/.
String? featureOf(String path) {
  final parts = path.split('/');
  return parts.length > 2 && parts[0] == 'features' ? parts[1] : null;
}

// The path under lib/ that [uri], written in the file at [from], points to;
// null for a dart: or another package's library.
String? resolve(String from, String uri) {
  const self = 'package:donhang_app/';
  if (uri.startsWith(self)) return uri.substring(self.length);
  if (uri.contains(':')) return null;
  final parts = from.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part == '..') {
      parts.removeLast();
    } else if (part != '.') {
      parts.add(part);
    }
  }
  return parts.join('/');
}
