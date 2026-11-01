import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';

/// Elevated white surface with soft depth — primary card container.
class MuSurface extends StatelessWidget {
  const MuSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusLg);
    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: radius,
        border: border,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: AppTheme.maroon.withValues(alpha: 0.06),
          highlightColor: AppTheme.maroon.withValues(alpha: 0.03),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
    return content;
  }
}

/// Frosted glass panel for overlays / top bars.
class MuGlass extends StatelessWidget {
  const MuGlass({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.opacity = 0.78,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusMd);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class MuIconBadge extends StatelessWidget {
  const MuIconBadge({
    super.key,
    required this.icon,
    this.color = AppTheme.maroon,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}
