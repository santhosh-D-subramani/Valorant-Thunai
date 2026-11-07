import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PresetSprayWheel extends StatelessWidget {
  final Map<String, String?> slotSprayIds;

  final Map<String, dynamic> spraysMap;

  final void Function(String slotId, String slotName) onTapSlot;

  const PresetSprayWheel({
    super.key,
    required this.slotSprayIds,
    required this.spraysMap,
    required this.onTapSlot,
  });

  static const _slotConfigs = [
    {
      'name': 'Top',
      'id': '0814b2fe-4512-60a4-5288-1fbdcec6ca48',
      'angle': -math.pi / 2,
    },
    {
      'name': 'Right',
      'id': '04af080a-4071-487b-61c0-5b9c0cfaac74',
      'angle': 0.0,
    },
    {
      'name': 'Bottom',
      'id': '5863985e-43ac-b05d-cb2d-139e72970014',
      'angle': math.pi / 2,
    },
    {
      'name': 'Left',
      'id': 'ec989a55-442a-5a9e-c852-510067ffbb3b',
      'angle': math.pi,
    },
  ];

  @override
  Widget build(BuildContext context) {
    const double size = 260.0;
    const double innerRadius = 64.0;
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _PresetSprayWheelPainter(
              baseColor: theme.scaffoldBackgroundColor,
              sectorColor: theme.cardColor,
              lineColor: theme.dividerColor,
              innerRadius: innerRadius,
            ),
          ),
          for (final config in _slotConfigs)
            _buildSlot(
              context,
              slotName: config['name'] as String,
              slotId: config['id'] as String,
              angle: config['angle'] as double,
              wheelSize: size,
            ),
        ],
      ),
    );
  }

  Widget _buildSlot(
    BuildContext context, {
    required String slotName,
    required String slotId,
    required double angle,
    required double wheelSize,
  }) {
    final theme = Theme.of(context);
    final sprayId = slotSprayIds[slotId];
    final spray = sprayId != null ? spraysMap[sprayId] : null;
    final iconUrl = spray != null
        ? ((spray['fullTransparentIcon'] ?? spray['displayIcon'] ?? '')
              as String)
        : '';

    final icon = iconUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: iconUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(),
            errorWidget: (context, url, error) => Icon(
              Icons.broken_image,
              color: theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
          )
        : Icon(Icons.add, color: theme.colorScheme.primary, size: 22);

    final iconRadius = wheelSize * 0.32;
    final iconSize = wheelSize * 0.24;
    final center = wheelSize / 2;
    final iconLeft = center + iconRadius * math.cos(angle) - iconSize / 2;
    final iconTop = center + iconRadius * math.sin(angle) - iconSize / 2;

    return SizedBox(
      width: wheelSize,
      height: wheelSize,
      child: Stack(
        children: [
          ClipPath(
            clipper: _PresetWheelSectorClipper(angle),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTapSlot(slotId, slotName),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: iconLeft,
            top: iconTop,
            width: iconSize,
            height: iconSize,
            child: IgnorePointer(child: icon),
          ),
        ],
      ),
    );
  }
}

class _PresetSprayWheelPainter extends CustomPainter {
  const _PresetSprayWheelPainter({
    required this.baseColor,
    required this.sectorColor,
    required this.lineColor,
    required this.innerRadius,
  });

  final Color baseColor;
  final Color sectorColor;
  final Color lineColor;
  final double innerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 3;
    final outer = Paint()..color = baseColor;
    canvas.drawCircle(center, radius, outer);

    final sector = Paint()..color = sectorColor.withValues(alpha: 0.7);
    final sectorRect = Rect.fromCircle(center: center, radius: radius - 5);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        sectorRect,
        -math.pi / 4 + i * math.pi / 2,
        math.pi / 2,
        true,
        sector,
      );
    }

    final outline = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, outline);

    final dividerUnderlay = Paint()
      ..color = baseColor
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.square;
    final divider = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    for (final angle in const [math.pi / 4, -math.pi / 4]) {
      final vector = Offset(math.cos(angle), math.sin(angle));
      final start = center - vector * radius;
      final end = center + vector * radius;
      canvas.drawLine(start, end, dividerUnderlay);
      canvas.drawLine(start, end, divider);
    }

    final inner = Paint()..color = baseColor;
    canvas.drawCircle(center, innerRadius, inner);
    final innerOutline = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, innerRadius, innerOutline);
  }

  @override
  bool shouldRepaint(covariant _PresetSprayWheelPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.sectorColor != sectorColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.innerRadius != innerRadius;
  }
}

class _PresetWheelSectorClipper extends CustomClipper<Path> {
  const _PresetWheelSectorClipper(this.angle);

  final double angle;

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.8;
    return Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(
        center.dx + radius * math.cos(angle - math.pi / 4),
        center.dy + radius * math.sin(angle - math.pi / 4),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        angle - math.pi / 4,
        math.pi / 2,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant _PresetWheelSectorClipper oldClipper) {
    return oldClipper.angle != angle;
  }
}
