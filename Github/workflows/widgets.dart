import 'dart:ui';
import 'package:flutter/material.dart';

/// کپسول شیشه‌ای با حاشیهٔ نورانی
class GlassCapsule extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  const GlassCapsule({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final br = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [BoxShadow(color: accent.withOpacity(0.25), blurRadius: 16)],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.white.withOpacity(0.07),
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: br,
                  border: Border.all(color: accent.withOpacity(0.6), width: 1.2),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// دایرهٔ فلزی منوی پایین
class MetalCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  const MetalCircle({super.key, required this.icon, required this.label, required this.onTap, this.size = 74});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Color(0xFFE9ECEF), Color(0xFF8E959B), Color(0xFF3C4147)],
              ),
              border: Border.all(color: accent.withOpacity(0.75), width: 2),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 18, spreadRadius: 1)],
            ),
            child: Icon(icon, size: size * 0.42, color: const Color(0xFF1B1E21)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 11)),
      ],
    );
  }
}

/// دکمهٔ برجستهٔ شبیه کلید کیبورد (سودوکو و بازی‌ها)
class Key3D extends StatefulWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  const Key3D({super.key, required this.child, required this.color, this.onTap, this.radius = 10});

  @override
  State<Key3D> createState() => _Key3DState();
}

class _Key3DState extends State<Key3D> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(widget.color, Colors.black, 0.28)!;
    final light = Color.lerp(widget.color, Colors.white, 0.35)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light, widget.color]),
          boxShadow: _down
              ? []
              : [
                  BoxShadow(color: dark, offset: const Offset(0, 3)),
                  const BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 5)),
                ],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}
