import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';

/// Soft fade + slide entrance used for cards and panels.
class MuFadeSlide extends StatefulWidget {
  const MuFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.04),
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<MuFadeSlide> createState() => _MuFadeSlideState();
}

class _MuFadeSlideState extends State<MuFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _timer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Scale-bounce favorite heart button.
class MuFavoriteButton extends StatefulWidget {
  const MuFavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.tooltip,
    this.size = 22,
  });

  final bool isFavorite;
  final Future<bool> Function()? onPressed;
  final String? tooltip;
  final double size;

  @override
  State<MuFavoriteButton> createState() => _MuFavoriteButtonState();
}

class _MuFavoriteButtonState extends State<MuFavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.28), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    _controller.forward(from: 0);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = ScaleTransition(
      scale: _scale,
      child: IconButton(
        tooltip: widget.tooltip ??
            (widget.isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos'),
        onPressed: widget.onPressed == null ? null : _handleTap,
        icon: Icon(
          widget.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: widget.isFavorite
              ? const Color(0xFFE11D48)
              : AppTheme.navy,
          size: widget.size,
        ),
      ),
    );
    return button;
  }
}

/// Subtle press-scale interaction for cards and buttons.
class MuScaleTap extends StatefulWidget {
  const MuScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.975,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  @override
  State<MuScaleTap> createState() => _MuScaleTapState();
}

class _MuScaleTapState extends State<MuScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Staggers child entrance animations in a list by index.
class MuStaggeredEntrance extends StatelessWidget {
  const MuStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 45),
    this.maxDelay = const Duration(milliseconds: 225),
  });

  final int index;
  final Widget child;
  final Duration step;
  final Duration maxDelay;

  @override
  Widget build(BuildContext context) {
    final delay = Duration(
      milliseconds:
          (index * step.inMilliseconds).clamp(0, maxDelay.inMilliseconds),
    );
    return MuFadeSlide(delay: delay, child: child);
  }
}
