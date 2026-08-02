import 'package:flutter/material.dart';
import '../services/shift_calculator.dart';
import '../services/app_theme.dart';

class ShiftBadge extends StatelessWidget {
  final ShiftType type;
  final double size;

  const ShiftBadge({super.key, required this.type, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (type == ShiftType.OFF) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '휴',
            style: TextStyle(
              fontSize: size * 0.46,
              fontWeight: FontWeight.w600,
              color: ShiftColors.offColor,
            ),
          ),
        ),
      );
    }

    final fontSize = type == ShiftType.DS ? size * 0.33 : size * 0.40;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ShiftColors.bgFor(type),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          type.label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: ShiftColors.textFor(type),
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class ShiftBadgeLarge extends StatelessWidget {
  final ShiftType type;

  const ShiftBadgeLarge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShiftBadge(type: type, size: 36),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (type.timeRange.isNotEmpty)
              Text(
                type.timeRange,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888780),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
