import 'package:flutter/material.dart';
import '../services/shift_calculator.dart';
import '../services/app_theme.dart';
import '../services/holiday_service.dart';
import '../widgets/shift_badge.dart';
import '../widgets/today_banner.dart';

class MyScheduleScreen extends StatefulWidget {
  final String myTeam;
  const MyScheduleScreen({super.key, required this.myTeam});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  late DateTime _month;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month);
  }

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() => setState(() => _month = DateTime(_month.year, _month.month + 1));

  @override
  Widget build(BuildContext context) {
    final stats = ShiftCalculator.getMonthStats(widget.myTeam, _month.year, _month.month);
    final remaining = ShiftCalculator.getRemainingWorkDays(widget.myTeam, _today);
    final upcoming = ShiftCalculator.getUpcoming(widget.myTeam, _today, 14);

    // 이번 주 (월요일~일요일 기준 or 이번주 전체)
    final weekStart = _today.subtract(Duration(days: _today.weekday % 7)); // 일요일 기준
    final thisWeek = List.generate(7, (i) {
      final d = weekStart.add(Duration(days: i));
      return MapEntry(d, ShiftCalculator.getShift(widget.myTeam, d));
    });

    const dowLabels = ['일', '월', '화', '수', '목', '금', '토'];
    const dowColors = [
      Color(0xFFE24B4A), Color(0xFF888780), Color(0xFF888780),
      Color(0xFF888780), Color(0xFF888780), Color(0xFF888780), Color(0xFF378ADD),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _prevMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_month.year}. ${_month.month.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F1FB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.myTeam}조',
                          style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Color(0xFF185FA5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TodayBanner(team: widget.myTeam, today: _today),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이번 주 카드
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '이번 주 근무',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: Color(0xFF888780),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(7, (i) {
                              final entry = thisWeek[i];
                              final d = entry.key;
                              final shift = entry.value;
                              final isToday = d.year == _today.year &&
                                  d.month == _today.month &&
                                  d.day == _today.day;
                              return Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      dowLabels[i],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: dowColors[i],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ShiftBadge(type: shift, size: 28),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${d.day}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                                        color: isToday
                                            ? const Color(0xFF378ADD)
                                            : const Color(0xFF888780),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 통계 카드
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        _StatCard(value: '${stats['total']}', label: '이번달 근무일'),
                        _StatCard(value: '$remaining', label: '남은 근무일'),
                        _StatCard(value: '${stats['G']}', label: '야간 횟수'),
                        _StatCard(value: '${stats['OFF']}', label: '휴무일'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 다가오는 일정
                    const Text(
                      '다가오는 일정',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: upcoming.take(10).map((entry) {
                          final d = entry.key;
                          final shift = entry.value;
                          const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                          final wd = weekdays[d.weekday - 1];
                          final holiday = HolidayService.getHolidayName(d);
                          final isHoliday = holiday != null;
                          return Container(
                            decoration: BoxDecoration(
                              color: isHoliday ? const Color(0xFFFFF5F5) : null,
                              border: const Border(
                                bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Column(
                                    children: [
                                      Text(
                                        '${d.day}',
                                        style: TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w600,
                                          color: isHoliday
                                              ? const Color(0xFFE24B4A)
                                              : const Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      Text(
                                        wd,
                                        style: const TextStyle(
                                          fontSize: 10, color: Color(0xFF888780),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            shift.name,
                                            style: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w500,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          if (isHoliday) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEEEE),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                holiday!,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xFFE24B4A),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (shift.timeRange.isNotEmpty)
                                        Text(
                                          shift.timeRange,
                                          style: const TextStyle(
                                            fontSize: 11, color: Color(0xFF888780),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                ShiftBadge(type: shift, size: 26),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF888780)),
          ),
        ],
      ),
    );
  }
}
