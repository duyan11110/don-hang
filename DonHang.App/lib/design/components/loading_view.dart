import 'package:flutter/material.dart';

// lesson: frontend.l3.component-library
/// What a whole screen shows while its data loads: a spinner in the middle.
///
/// Use it as the body of a screen that has nothing to show yet. Not for a
/// part of a screen that is still loading while the rest is shown, and not
/// for a button that is busy: disable the button instead.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
