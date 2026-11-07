import 'dart:math' as math;

import 'package:flutter/material.dart';

class WavyLinearProgressIndicator extends StatelessWidget {
  const WavyLinearProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.strokeWidth = 3.5,
    this.amplitude = 2.5,
    this.wavelength = 28.0,
    this.gap = 4.0,
    this.height = 10.0,
  });

  final double? value;

  final Color? color;

  final Color? backgroundColor;

  final double strokeWidth;

  final double amplitude;

  final double wavelength;

  final double gap;

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    final progress = (value ?? 0.0).clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavyLinearProgressPainter(
          progress: progress,
          color: effectiveColor,
          backgroundColor: effectiveBackgroundColor,
          strokeWidth: strokeWidth,
          amplitude: amplitude,
          wavelength: wavelength,
          gap: gap,
        ),
      ),
    );
  }
}

class _WavyLinearProgressPainter extends CustomPainter {
  _WavyLinearProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.amplitude,
    required this.wavelength,
    required this.gap,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double amplitude;
  final double wavelength;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final activeWidth = size.width * progress;

    final trackPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (progress <= 0.0) {
      canvas.drawLine(Offset(0, cy), Offset(size.width, cy), trackPaint);
    } else if (progress < 1.0) {
      final trackStart = math.min(size.width, activeWidth + gap);
      if (trackStart < size.width) {
        canvas.drawLine(
          Offset(trackStart, cy),
          Offset(size.width, cy),
          trackPaint,
        );
      }
    }

    if (activeWidth > 0.0) {
      final activePaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(0, cy);

      const step = 1.0;
      for (double x = step; x <= activeWidth; x += step) {
        final y = cy + amplitude * math.sin(2 * math.pi * (x / wavelength));
        path.lineTo(x, y);
      }

      final endY =
          cy + amplitude * math.sin(2 * math.pi * (activeWidth / wavelength));
      path.lineTo(activeWidth, endY);

      canvas.drawPath(path, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavyLinearProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.gap != gap;
  }
}
