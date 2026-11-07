import 'dart:math' as math;

import 'package:flutter/material.dart';

class HangingSasukeCharm extends StatefulWidget {
  final VoidCallback onTap;

  const HangingSasukeCharm({super.key, required this.onTap});

  @override
  State<HangingSasukeCharm> createState() => _HangingSasukeCharmState();
}

class _HangingSasukeCharmState extends State<HangingSasukeCharm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swingController;
  late final Animation<double> _swing;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _swingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _swing = Tween<double>(begin: -0.055, end: 0.055).animate(
      CurvedAnimation(parent: _swingController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _swingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _swing,
        builder: (context, child) {
          return SizedBox(
            width: 104,
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.86),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF4655),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  child: Transform.rotate(
                    angle: _swing.value,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 2,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: Colors.white.withValues(alpha: 0.78),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB8A8FF)
                                    .withValues(alpha: 0.55),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        AnimatedScale(
                          scale: _isPressed ? 0.92 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOutBack,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.translate(
                                offset: const Offset(3, 5),
                                child: Opacity(
                                  opacity: 0.3,
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withValues(alpha: 0.9),
                                      BlendMode.srcIn,
                                    ),
                                    child: Transform.rotate(
                                      angle: math.pi,
                                      child: Image.asset(
                                        'assets/sasuke.webp',
                                        height: 108,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C5CFF)
                                          .withValues(alpha: 0.26),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Transform.rotate(
                                  angle: math.pi,
                                  child: Image.asset(
                                    'assets/sasuke.webp',
                                    height: 110,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 72,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: Colors.black.withValues(alpha: 0.24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
