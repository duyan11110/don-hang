import 'package:flutter/material.dart';

import 'design/brand.dart';
import 'design/theme.dart';
import 'design/tokens.dart';
import 'gallery/examples.dart';

// lesson: frontend.l3.component-gallery
// A second entry point: flutter run -d chrome -t lib/gallery_main.dart.
// It shows every gallery example in the light and the dark theme, side by
// side. `flutter build web` builds lib/main.dart, which never imports this
// file, so none of the gallery reaches the bundle customers download.
void main() => runApp(const ComponentGallery());

class ComponentGallery extends StatelessWidget {
  const ComponentGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DonHang.App components',
      theme: buildTheme(donHangBrand, Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text('DonHang.App components')),
        body: ListView(
          padding: Insets.screen,
          children: [for (final example in galleryExamples) _section(context, example)],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, GalleryExample example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(example.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(child: _inTheme(Brightness.light, example.widget)),
              const SizedBox(width: Space.lg),
              Expanded(child: _inTheme(Brightness.dark, example.widget)),
            ],
          ),
        ],
      ),
    );
  }

  // The example on its theme's surface, in a box of a fixed height so that
  // LoadingView and MessageView, which fill the space they get, can show.
  Widget _inTheme(Brightness brightness, Widget example) {
    return Theme(
      data: buildTheme(donHangBrand, brightness),
      child: Builder(
        builder: (context) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(height: 160, child: Align(alignment: Alignment.topCenter, child: example)),
        ),
      ),
    );
  }
}
