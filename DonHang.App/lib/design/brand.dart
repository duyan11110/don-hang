import 'package:flutter/material.dart';

import 'status_colors.dart';

// lesson: frontend.l3.brand-themes
// One brand's token values: its seed color, from which ColorScheme grows
// every Material role, and its status colors for light and dark. A second
// brand would be a second Brand, not a second copy of any screen. This is
// the only file under lib/ allowed to write a color (no_raw_colors_test).
class Brand {
  final Color seed;
  final StatusColors lightStatus;
  final StatusColors darkStatus;

  const Brand({required this.seed, required this.lightStatus, required this.darkStatus});

  StatusColors statusColors(Brightness brightness) =>
      brightness == Brightness.dark ? darkStatus : lightStatus;
}

// lesson: frontend.l3.brand-themes
// The one brand DonHang.App ships. Each "on" color keeps a contrast of at
// least 4.5:1 with its background (accessibility-checks tests it).
const donHangBrand = Brand(
  seed: Colors.indigo,
  lightStatus: StatusColors(
    warning: Color(0xFF7A5900),
    onWarning: Color(0xFFFFFFFF),
    success: Color(0xFF1B6E2E),
    onSuccess: Color(0xFFFFFFFF),
  ),
  darkStatus: StatusColors(
    warning: Color(0xFFF5C451),
    onWarning: Color(0xFF3D2E00),
    success: Color(0xFF8FD99A),
    onSuccess: Color(0xFF00391A),
  ),
);
