import 'package:flutter/material.dart';
import '../services/shift_calculator.dart';
import '../services/app_theme.dart';
import 'shift_badge.dart';

class TodayBanner extends StatelessWidget {
  final String team;
  final DateTime today;

  const TodayBanner({super.key, required this.team, required this.today});

  @override
  Widget build(BuildContext context) {
    final todayShift = ShiftCalculator.getShift(team, today);
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowShift = ShiftCalculator.getShift(team, tomorrow);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ShiftColors.myTeamBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘  $team조  ·  ${today.month}월 ${today.day}일',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3B6D11),
                ),
              ),
              const SizedBox(height: 6),
              ShiftBadgeLarge(type: todayShift),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '내일',
                style: TextStyle(fontSize: 10, color: Color(0xFF3B6D11)),
              ),
              const SizedBox(height: 4),
              ShiftBadge(type: tomorrowShift, size: 32),
            ],
          ),
        ],
      ),
    );
  }
}
