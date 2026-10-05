import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/gallery/examples.dart';

import 'example_frame.dart';

void main() {
  // lesson: frontend.l3.accessibility-checks
  // Every gallery example, in the light and the dark theme, against three
  // guidelines flutter_test can measure on what the test has built: text
  // contrast (4.5:1, or 3:1 for large text), tap targets of at least
  // 48 × 48, and a label on everything that can be tapped.
  for (final example in galleryExamples) {
    for (final brightness in Brightness.values) {
      testWidgets('${example.name} (${brightness.name}) meets the guidelines', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(exampleFrame(example, brightness));

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  }
}
