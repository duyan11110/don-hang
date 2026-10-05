import 'package:flutter/material.dart';

import 'package:donhang_app/design/brand.dart';
import 'package:donhang_app/design/theme.dart';
import 'package:donhang_app/gallery/examples.dart';

// Shared by the accessibility and the golden test: one gallery example in
// the app's theme of [brightness], on that theme's surface, in a box of
// 360 × 160 logical pixels, the same box for every run.
const frameKey = Key('example-frame');

Widget exampleFrame(GalleryExample example, Brightness brightness) {
  final theme = buildTheme(donHangBrand, brightness);
  return MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: frameKey,
          child: SizedBox(
            width: 360,
            height: 160,
            child: Material(
              color: theme.colorScheme.surface,
              child: Align(alignment: Alignment.topCenter, child: example.widget),
            ),
          ),
        ),
      ),
    ),
  );
}
