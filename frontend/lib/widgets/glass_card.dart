import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderOpacity = 0.1,
    this.colorOpacity = 0.05,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double borderOpacity;
  final double colorOpacity;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(colorOpacity),
            borderRadius: br,
            border: Border.all(
              color: Colors.white.withOpacity(borderOpacity),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
