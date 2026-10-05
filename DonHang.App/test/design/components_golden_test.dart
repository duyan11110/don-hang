// lesson: frontend.l3.golden-tests
// Tagged `golden` (declared in dart_test.yaml): pixels differ a little from
// one operating system to another, so these run, and their images are made,
// only on the Linux CI runner. Elsewhere: flutter test --exclude-tags golden.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/gallery/examples.dart';

import 'example_frame.dart';

void main() {
  // lesson: frontend.l3.golden-tests
  // Each gallery example becomes an image and is compared, pixel by pixel,
  // with test/design/goldens/<name>_<light|dark>.png in the repository.
  // `flutter test --update-goldens` writes those files instead of comparing.
  for (final example in galleryExamples) {
    for (final brightness in Brightness.values) {
      testWidgets('${example.name} (${brightness.name}) looks as approved', (tester) async {
        await tester.pumpWidget(exampleFrame(example, brightness));

        await expectLater(
          find.byKey(frameKey),
          matchesGoldenFile('goldens/${example.name}_${brightness.name}.png'),
        );
      });
    }
  }
}
