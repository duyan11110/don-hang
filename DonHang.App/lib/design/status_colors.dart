import 'package:flutter/material.dart';

// lesson: frontend.l3.theme-extension
// lesson: frontend.l3.accessibility-checks
// Color roles ColorScheme does not have: a warning that is not an error, and
// a success. Each comes with its "on" color for text on top of it. The light
// and the dark theme register their own values (see brand.dart), so text on
// a warning stays readable in both.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color warning;
  final Color onWarning;
  final Color success;
  final Color onSuccess;

  const StatusColors({
    required this.warning,
    required this.onWarning,
    required this.success,
    required this.onSuccess,
  });

  @override
  StatusColors copyWith({Color? warning, Color? onWarning, Color? success, Color? onSuccess}) {
    return StatusColors(
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
    );
  }

  // lesson: frontend.l3.theme-extension
  // Called while the theme changes, with t going from 0 to 1, so the colors
  // move gradually from the old theme's values to the new one's.
  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
    );
  }
}
