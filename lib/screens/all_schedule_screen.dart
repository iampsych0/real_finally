import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shift_calculator.dart';
import '../services/override_service.dart';
import '../services/app_theme.dart';
import '../services/holiday_service.dart';
import '../widgets/shift_badge.dart';
import '../widgets/today_banner.dart';

class AllScheduleScreen extends StatefulWidget {
  final String myTeam;
  const AllScheduleScreen({super.key, required this.myTeam});

  @override
  State<AllScheduleScreen> createState() => _AllScheduleScreenState();
}

class _AllScheduleScreenState extends State<AllScheduleScreen> {
  static const _alarmChannel = MethodChannel('com.example.cspi/alarm');

  Future<void> _refreshAlarm() async {
    // override가 바뀌면 오늘 근무 기준 알람을 다시 예약
    await _alarmChannel.invokeMethod('scheduleDailyAlarm');
  }

  late DateTime _month;
  final DateTime _today = DateTime.now();
  bool _showMyOnly = false;

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month);
  }

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() => setState(() => _month = DateTime(_month.year, _month.month + 1));

  Future<void> _editShift(String team, DateTime date) async {
    final options = <(String, ShiftType, Color)>[
      ('주간 (D)', ShiftType.D, const Color(0xFFF5C147)),
      ('저녁 (S)', ShiftType.S, const Color(0xFF888780)),
      ('야간 (G)', ShiftType.G, const Color(0xFF2B2B2B)),
      ('주간+저녁 (DS)', ShiftType.DS, const Color(0xFF378ADD)),
      ('휴무', ShiftType.OFF, const Color(0xFFE24B4A)),
    ];
    final dateStr = '${date.month}월 ${date.day}일';
    final current = ShiftCalculator.getShift(team, date);
    final isOverridden = ShiftCalculator.hasOverride(team, date);

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('$team조 · $dateStr 근무 변경',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...options.map((o) => ListTile(
              leading: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: o.$3, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  o.$2 == ShiftType.OFF ? '휴' : shiftTypeToKey(o.$2),
                  style: TextStyle(
                    color: (o.$2 == ShiftType.D) ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              title: Text(o.$1),
              trailing: current == o.$2
                  ? const Icon(Icons.check, color: Color(0xFF378ADD))
                  : null,
              onTap: () => Navigator.pop(ctx, o.$2),
            )),
            if (isOverridden)
              ListTile(
                leading: const Icon(Icons.restart_alt, color: Color(0xFF888780)),
                title: const Text('자동 계산으로 되돌리기'),
                onTap: () => Navigator.pop(ctx, 'reset'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((result) async {
      if (result == null) return;
      if (result == 'reset') {
        await OverrideService.clearOverride(team, date);
      } else if (result is ShiftType) {
        await OverrideService.setOverride(team, date, result);
      }
      if (mounted) setState(() {});
      // 알람도 오늘 근무가 바뀌었으면 재등록
      try {
        await _refreshAlarm();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final teams = _showMyOnly ? [widget.myTeam] : ['A', 'B', 'C', 'D'];
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final holidays = HolidayService.getMonthHolidays(_month.year, _month.month);

    final List<List<int?>> weeks = [];
    List<int?> week = List.filled(7, null);
    int dayCount = 0;
    for (int col = startWeekday; col < 7; col++) {
      week[col] = ++dayCount;
    }
    weeks.add(List.from(week));
    while (dayCount < daysInMonth) {
      week = List.filled(7, null);
      for (int col = 0; col < 7 && dayCount < daysInMonth; col++) {
        week[col] = ++dayCount;
      }
      weeks.add(List.from(week));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
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
                      _ToggleButton(
                        options: const ['전체', '내 조'],
                        selected: _showMyOnly ? 1 : 0,
                        onChanged: (i) => setState(() => _showMyOnly = i == 1),
                      ),
                    ],
                  ),
                  TodayBanner(team: widget.myTeam, today: _today),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _DowHeader(),
                      ...weeks.map((week) => _WeekBlock(
                        week: week,
                        month: _month,
                        today: _today,
                        teams: teams,
                        myTeam: widget.myTeam,
                        holidays: holidays,
                        onEditShift: _editShift,
                      )),
                      _Legend(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _ToggleButton({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected ? Border.all(color: Colors.black12, width: 0.5) : null,
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF888780),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DowHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    const colors = [
      Color(0xFFE24B4A), Color(0xFF888780), Color(0xFF888780),
      Color(0xFF888780), Color(0xFF888780), Color(0xFF888780), Color(0xFF378ADD),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40),
          ...List.generate(7, (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                days[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: colors[i], fontWeight: FontWeight.w500),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _WeekBlock extends StatelessWidget {
  final List<int?> week;
  final DateTime month;
  final DateTime today;
  final List<String> teams;
  final String myTeam;
  final Map<int, String> holidays;
  final void Function(String team, DateTime date) onEditShift;

  const _WeekBlock({
    required this.week,
    required this.month,
    required this.today,
    required this.teams,
    required this.myTeam,
    required this.holidays,
    required this.onEditShift,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 날짜 + 공휴일 이름 행
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 40),
              ...List.generate(7, (col) {
                final day = week[col];
                if (day == null) return const Expanded(child: SizedBox(height: 28));
                final date = DateTime(month.year, month.month, day);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isSun = col == 0;
                final isSat = col == 6;
                final holiday = holidays[day];
                final isHoliday = holiday != null;
                // 공휴일이면 날짜도 빨간색
                final dayColor = isToday
                    ? Colors.white
                    : (isSun || isHoliday)
                        ? const Color(0xFFE24B4A)
                        : isSat
                            ? const Color(0xFF378ADD)
                            : const Color(0xFF555555);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 공휴일 이름 (있을 때만)
                        if (isHoliday)
                          Text(
                            _shortHolidayName(holiday!),
                            style: const TextStyle(
                              fontSize: 7,
                              color: Color(0xFFE24B4A),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          )
                        else
                          const SizedBox(height: 9),
                        // 날짜 숫자
                        Container(
                          width: 18,
                          height: 18,
                          decoration: isToday
                              ? const BoxDecoration(
                                  color: Color(0xFF378ADD),
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                                color: dayColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        // 조별 근무 행
        ...teams.map((team) {
          final isMyTeam = team == myTeam;
          return Container(
            decoration: BoxDecoration(
              color: isMyTeam ? const Color(0xFFF0F7FF) : null,
              border: const Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Text(
                      '$team조',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isMyTeam ? FontWeight.w700 : FontWeight.w500,
                        color: isMyTeam ? const Color(0xFF185FA5) : const Color(0xFF888780),
                      ),
                    ),
                  ),
                ),
                ...List.generate(7, (col) {
                  final day = week[col];
                  if (day == null) return const Expanded(child: SizedBox(height: 40));
                  final date = DateTime(month.year, month.month, day);
                  final shift = ShiftCalculator.getShift(team, date);
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  final isHoliday = holidays.containsKey(day);
                  final hasOverride = ShiftCalculator.hasOverride(team, date);
                  return Expanded(
                    child: GestureDetector(
                      onLongPress: () => onEditShift(team, date),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 공휴일 배경 (연한 빨강)
                            if (isHoliday)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEEEE),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            // 오늘+내조 테두리
                            if (isToday && isMyTeam)
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF378ADD),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ShiftBadge(type: shift, size: 24),
                            // 수동 변경 표시 (우상단 작은 점)
                            if (hasOverride)
                              Positioned(
                                top: 2,
                                right: 6,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF378ADD),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 공휴일 이름 축약 (7px 폰트라 짧게)
  String _shortHolidayName(String name) {
    const map = {
      '신정': '신정',
      '설날 연휴': '연휴',
      '설날': '설날',
      '삼일절': '삼일절',
      '삼일절 대체': '대체',
      '어린이날': '어린이',
      '어린이날 대체': '대체',
      '부처님오신날': '석가탄신',
      '부처님오신날 대체': '대체',
      '현충일': '현충일',
      '광복절': '광복절',
      '광복절 대체': '대체',
      '추석 연휴': '연휴',
      '추석': '추석',
      '추석 대체': '대체',
      '개천절': '개천절',
      '한글날': '한글날',
      '크리스마스': '성탄절',
      '전국동시지방선거': '선거일',
    };
    return map[name] ?? name;
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (ShiftType.D, '주간'),
      (ShiftType.G, '야간'),
      (ShiftType.S, '저녁'),
      (ShiftType.DS, '주+저녁'),
      (ShiftType.OFF, '휴무'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          ...items.map((item) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShiftBadge(type: item.$1, size: 16),
              const SizedBox(width: 3),
              Text(item.$2, style: const TextStyle(fontSize: 10, color: Color(0xFF888780))),
            ],
          )),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEEEE),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('휴', style: TextStyle(fontSize: 7, color: Color(0xFFE24B4A))),
                ),
              ),
              const SizedBox(width: 3),
              const Text('공휴일', style: TextStyle(fontSize: 10, color: Color(0xFF888780))),
            ],
          ),
        ],
      ),
    );
  }
}
