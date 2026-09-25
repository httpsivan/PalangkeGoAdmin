import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_motion.dart';

class AnimatedPageSwitcher extends StatelessWidget {
  const AnimatedPageSwitcher({
    super.key,
    required this.route,
    required this.child,
  });

  final String route;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedSwitcher(
          duration: AppMotion.duration(context, const Duration(milliseconds: 140)),
          reverseDuration:
              AppMotion.duration(context, const Duration(milliseconds: 100)),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topLeft,
              children: <Widget>[
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
          child: KeyedSubtree(key: ValueKey(route), child: child),
        ),
      );
}

class AnimatedHoverContainer extends StatefulWidget {
  const AnimatedHoverContainer({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool enabled;

  @override
  State<AnimatedHoverContainer> createState() => _AnimatedHoverContainerState();
}

class AnimatedButtonFeedback extends StatefulWidget {
  const AnimatedButtonFeedback({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<AnimatedButtonFeedback> createState() => _AnimatedButtonFeedbackState();
}

class _AnimatedButtonFeedbackState extends State<AnimatedButtonFeedback> {
  bool hovering = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.enabled && pressed
        ? .97
        : widget.enabled && hovering
            ? 1.008
            : 1.0;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => widget.enabled ? setState(() => hovering = true) : null,
      onExit: (_) => widget.enabled ? setState(() => hovering = false) : null,
      child: Listener(
        onPointerDown:
            widget.enabled ? (_) => setState(() => pressed = true) : null,
        onPointerUp:
            widget.enabled ? (_) => setState(() => pressed = false) : null,
        onPointerCancel:
            widget.enabled ? (_) => setState(() => pressed = false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: AppMotion.duration(
            context,
            pressed ? AppMotion.press : AppMotion.hover,
          ),
          curve: AppMotion.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class _AnimatedHoverContainerState extends State<AnimatedHoverContainer> {
  bool hovering = false;
  bool pressed = false;

  void _setHovering(bool value) {
    if (hovering == value || !widget.enabled) return;
    setState(() => hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && widget.onTap != null;
    final scale = pressed
        ? .985
        : hovering && interactive
            ? 1.006
            : 1.0;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? widget.onTap : null,
        onTapDown: interactive ? (_) => setState(() => pressed = true) : null,
        onTapUp: interactive ? (_) => setState(() => pressed = false) : null,
        onTapCancel: interactive ? () => setState(() => pressed = false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: AppMotion.duration(
            context,
            pressed ? AppMotion.press : AppMotion.hover,
          ),
          curve: AppMotion.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.begin = const Offset(0, .025),
    this.duration = AppMotion.component,
  });

  final Widget child;
  final Duration delay;
  final Offset begin;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> opacity;
  late final Animation<Offset> slide;
  bool started = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final curve = CurvedAnimation(parent: controller, curve: AppMotion.easeOut);
    opacity = curve.drive(CurveTween(curve: Curves.easeOut));
    slide = Tween<Offset>(begin: widget.begin, end: Offset.zero).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    _start(AppMotion.reducedMotion(context));
  }

  Future<void> _start(bool reducedMotion) async {
    if (!reducedMotion && widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (mounted) controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reducedMotion(context)) {
      return FadeTransition(opacity: opacity, child: widget.child);
    }
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}

class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = AppMotion.chart,
    this.animateFromZero = true,
  });

  final String value;
  final TextStyle? style;
  final Duration duration;
  final bool animateFromZero;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  _CounterParts? parts;
  double from = 0;
  double to = 0;
  double displayed = 0;

  @override
  void initState() {
    super.initState();
    parts = _CounterParts.tryParse(widget.value);
    to = parts?.number ?? 0;
    from = widget.animateFromZero ? 0 : to;
    displayed = from;
    controller = AnimationController(vsync: this, duration: widget.duration);
    if (parts != null && from != to) controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final next = _CounterParts.tryParse(widget.value);
    from = parts == null ? (next?.number ?? 0) : displayed;
    to = next?.number ?? 0;
    parts = next;
    if (next == null) {
      controller.value = 1;
    } else {
      controller
        ..duration = widget.duration
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parts;
    if (parsed == null) {
      return AnimatedSwitcher(
        duration: AppMotion.duration(context, AppMotion.component),
        child: Text(widget.value,
            key: ValueKey(widget.value), style: widget.style),
      );
    }
    if (AppMotion.reducedMotion(context)) {
      return Text(widget.value, style: widget.style);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        displayed = ui.lerpDouble(from, to, controller.value) ?? to;
        return Text(parsed.format(displayed), style: widget.style);
      },
    );
  }
}

class _CounterParts {
  const _CounterParts({
    required this.prefix,
    required this.suffix,
    required this.number,
    required this.decimalDigits,
    required this.minimumIntegerDigits,
  });

  final String prefix;
  final String suffix;
  final double number;
  final int decimalDigits;
  final int minimumIntegerDigits;

  static _CounterParts? tryParse(String value) {
    final match =
        RegExp(r'^([^\d-]*)(-?[\d,]+(?:\.\d+)?)(.*)$').firstMatch(value);
    if (match == null) return null;
    final rawNumber = match.group(2)!.replaceAll(',', '');
    final number = double.tryParse(rawNumber);
    if (number == null) return null;
    return _CounterParts(
      prefix: match.group(1)!,
      suffix: match.group(3)!,
      number: number,
      decimalDigits:
          rawNumber.contains('.') ? rawNumber.split('.').last.length : 0,
      minimumIntegerDigits: rawNumber.split('.').first.length,
    );
  }

  String format(double value) {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: 'en_US',
      decimalDigits: decimalDigits,
    );
    var formatted = formatter.format(value);
    final sign = formatted.startsWith('-') ? '-' : '';
    final unsigned = sign.isEmpty ? formatted : formatted.substring(1);
    final separator = unsigned.indexOf('.');
    final integer =
        separator == -1 ? unsigned : unsigned.substring(0, separator);
    final digits = integer.replaceAll(',', '').length;
    if (digits < minimumIntegerDigits) {
      formatted = '$sign${'0' * (minimumIntegerDigits - digits)}$unsigned';
    }
    return '$prefix$formatted$suffix';
  }
}
