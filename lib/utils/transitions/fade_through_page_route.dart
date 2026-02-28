import 'package:flutter/material.dart';

class FadeThroughPageRoute<T> extends PageRouteBuilder<T> {
  FadeThroughPageRoute({
    required this.builder,
    super.settings,
    this.duration = const Duration(milliseconds: 180),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) {
            return builder(context);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation.drive(
                CurveTween(curve: Curves.easeOutCubic),
              ),
              child: child,
            );
          },
        );

  final WidgetBuilder builder;
  final Duration duration;
}