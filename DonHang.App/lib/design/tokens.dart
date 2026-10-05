import 'package:flutter/widgets.dart';

// lesson: frontend.l3.semantic-tokens
// A short spacing scale: the only sizes a gap or a padding may take.
class Space {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

// Semantic tokens: named for where they apply, built from the scale above.
// Changing Insets.screen moves every screen's edge and nothing else.
class Insets {
  static const EdgeInsets screen = EdgeInsets.all(Space.lg);
  static const EdgeInsets tile = EdgeInsets.all(Space.md);
}

class Sizes {
  // The smallest tap target, in logical pixels (frontend.l1.accessibility-basics).
  static const double minTapTarget = 48;
  // One row of ProductCatalog's grid: a tile's tap target and its padding.
  static const double gridRow = 72;
}
