import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/glass_preferences.dart';

/// A bounded Flutter glass treatment for navigation and controls.
/// This approximates the material; it is not Apple's native Liquid Glass API.
class GlassSurface extends StatelessWidget {
  const GlassSurface(
      {super.key,
      required this.child,
      this.radius = 28,
      this.padding = EdgeInsets.zero});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: GlassPreferences.reduceTransparency,
        builder: (context, reduceTransparency, _) {
          final theme = Theme.of(context);
          final dark = theme.brightness == Brightness.dark;
          final opaque =
              reduceTransparency || MediaQuery.highContrastOf(context);
          final base = dark ? const Color(0xFF202C3C) : Colors.white;
          final borderRadius = BorderRadius.circular(radius);
          final surface = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: opaque ? 1 : 0.90),
                  base.withValues(alpha: opaque ? 1 : 0.74)
                ],
              ),
              border: Border.all(
                  color: opaque
                      ? theme.colorScheme.outline
                      : Colors.white.withValues(alpha: dark ? 0.18 : 0.82)),
            ),
            child: Padding(padding: padding, child: child),
          );
          return DecoratedBox(
            decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.18 : 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ]),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: opaque
                  ? surface
                  : BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: surface,
                    ),
            ),
          );
        },
      );
}
