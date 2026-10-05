import 'package:flutter/material.dart';

import '../design/components/loading_view.dart';
import '../design/components/message_view.dart';
import '../design/components/status_banner.dart';

// One shared component in one state, under a name the gallery shows and
// the golden test uses for its image file.
class GalleryExample {
  final String name;
  final Widget widget;

  const GalleryExample(this.name, this.widget);
}

// lesson: frontend.l3.component-gallery
// lesson: frontend.l3.accessibility-checks
// Every shared component in every variant, kept in one list: the gallery
// shows it, the accessibility test checks each entry in both themes, and
// the golden test keeps an image of each. A new variant added here is
// shown, checked and pictured without touching the three.
final List<GalleryExample> galleryExamples = [
  const GalleryExample('loading_view', LoadingView()),
  const GalleryExample('message_view', MessageView(message: 'No products yet.')),
  GalleryExample('message_view_action', MessageView(message: 'Could not load products.', actionLabel: 'Reload', onAction: () {})),
  for (final tone in StatusTone.values)
    GalleryExample('status_banner_${tone.name}', StatusBanner(message: 'A ${tone.name} message for the customer.', tone: tone)),
  GalleryExample(
    'status_banner_action',
    StatusBanner(message: 'Not placed: product 3 no longer exists.', tone: StatusTone.error, actionLabel: 'Remove', onAction: () {}),
  ),
];
