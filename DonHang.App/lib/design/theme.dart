import 'package:flutter/material.dart';

import 'brand.dart';

// lesson: frontend.l3.brand-themes
// lesson: frontend.l3.theme-extension
// The only code that turns a brand's token values into a ThemeData.
// main.dart calls it twice: once for the light theme, once for the dark.
// `extensions` adds the roles ColorScheme lacks; a widget reads them with
// Theme.of(context).extension<StatusColors>().
ThemeData buildTheme(Brand brand, Brightness brightness) {
  return ThemeData(
    colorSchemeSeed: brand.seed,
    brightness: brightness,
    extensions: [brand.statusColors(brightness)],
  );
}
