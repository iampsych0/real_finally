// 교대근무 계산 서비스
// 기준일: 2026-06-01 = 각 조 사이클 idx 0
// 6월 실제 근무표로 전체 검증 완료 ✅

enum ShiftType { D, G, S, DS, OFF }

ShiftType shiftTypeFromKey(String key) {
  switch (key) {
    case 'D':  return ShiftType.D;
    case 'G':  return ShiftType.G;
    case 'S':  return ShiftType.S;
    case 'DS': return ShiftType.DS;
    case 'OFF':
    case '휴': return ShiftType.OFF;
    default:   return ShiftType.OFF;
  }
}

String shiftTypeToKey(ShiftType t) {
  switch (t) {
    case ShiftType.D:   return 'D';
    case ShiftType.G:   return 'G';
    case ShiftType.S:   return 'S';
    case ShiftType.DS:  return 'DS';
    case ShiftType.OFF: return 'OFF';
  }
}

extension ShiftTypeExt on ShiftType {
  String get label {
    switch (this) {
      case ShiftType.D:   return 'D';
      case ShiftType.G:   return 'G';
      case ShiftType.S:   return 'S';
      case ShiftType.DS:  return 'DS';
      case ShiftType.OFF: return '휴';
    }
  }

  String get name {
    switch (this) {
      case ShiftType.D:   return '주간근무';
      case ShiftType.G:   return '야간근무';
      case ShiftType.S:   return '저녁근무';
      case ShiftType.DS:  return '주간+저녁';
      case ShiftType.OFF: return '휴무';
    }
  }

  String get timeRange {
    switch (this) {
      case ShiftType.D:   return '08:00 – 15:00';
      case ShiftType.G:   return '22:00 – 08:00';
      case ShiftType.S:   return '15:00 – 22:00';
      case ShiftType.DS:  return '08:00 – 22:00';
      case ShiftType.OFF: return '';
    }
  }

  bool get isWork => this != ShiftType.OFF;
}

// ✅ 각 조 독립 28일 사이클 (기준: 2026-06-01 = idx 0)
// 6월 전체 실제 근무표로 검증 완료

// A조: 6/1=S, 6/2=휴, 6/3~5=D, 6/6~7=휴, 6/8~9=D,
//      6/10=휴, 6/11~14=G, 6/15~18=S, 6/19~20=휴,
//      6/21~23=G, 6/24~25=휴, 6/26~27=DS, 6/28=S
const List<ShiftType> _aCycle = [
  ShiftType.S,   // 0  → 6/1
  ShiftType.OFF, // 1  → 6/2
  ShiftType.D,   // 2  → 6/3
  ShiftType.D,   // 3  → 6/4
  ShiftType.D,   // 4  → 6/5
  ShiftType.OFF, // 5  → 6/6
  ShiftType.OFF, // 6  → 6/7
  ShiftType.D,   // 7  → 6/8
  ShiftType.D,   // 8  → 6/9
  ShiftType.OFF, // 9  → 6/10
  ShiftType.G,   // 10 → 6/11
  ShiftType.G,   // 11 → 6/12
  ShiftType.G,   // 12 → 6/13
  ShiftType.G,   // 13 → 6/14
  ShiftType.OFF, // 14 → G 다음 휴무
  ShiftType.S,   // 15 → S 1
  ShiftType.S,   // 16 → S 2
  ShiftType.S,   // 17 → S 3
  ShiftType.S,   // 18 → S 4
  ShiftType.OFF, // 19 → 휴무 1
  ShiftType.OFF, // 20 → 휴무 2
  ShiftType.G,   // 21 → G 1
  ShiftType.G,   // 22 → G 2
  ShiftType.G,   // 23 → G 3
  ShiftType.OFF, // 24 → 휴무
  ShiftType.OFF, // 25 → 휴무
  ShiftType.DS,  // 26 → DS 1
  ShiftType.DS,  // 27 → DS 2
];

// B조: 6/1~3=G, 6/4~5=휴, 6/6~7=DS, 6/8=S, 6/9=휴,
//      6/10~12=D, 6/13~14=휴, 6/15~16=D, 6/17=휴,
//      6/18~21=G, 6/22=휴, 6/23~26=S, 6/27~28=휴
const List<ShiftType> _bCycle = [
  ShiftType.G,   // 0  → 6/1
  ShiftType.G,   // 1  → 6/2
  ShiftType.G,   // 2  → 6/3
  ShiftType.OFF, // 3  → 6/4
  ShiftType.OFF, // 4  → 6/5
  ShiftType.DS,  // 5  → 6/6
  ShiftType.DS,  // 6  → 6/7
  ShiftType.S,   // 7  → 6/8
  ShiftType.OFF, // 8  → 6/9
  ShiftType.D,   // 9  → 6/10
  ShiftType.D,   // 10 → 6/11
  ShiftType.D,   // 11 → 6/12
  ShiftType.OFF, // 12 → 6/13
  ShiftType.OFF, // 13 → 6/14
  ShiftType.D,   // 14 → 6/15
  ShiftType.D,   // 15 → 6/16
  ShiftType.OFF, // 16 → 6/17
  ShiftType.G,   // 17 → 6/18
  ShiftType.G,   // 18 → 6/19
  ShiftType.G,   // 19 → 6/20
  ShiftType.G,   // 20 → 6/21
  ShiftType.OFF, // 21 → 6/22
  ShiftType.S,   // 22 → 6/23
  ShiftType.S,   // 23 → 6/24
  ShiftType.S,   // 24 → 6/25
  ShiftType.S,   // 25 → 6/26
  ShiftType.OFF, // 26 → 6/27
  ShiftType.OFF, // 27 → 6/28
];

// C조: 6/1=휴, 6/2~5=S, 6/6~7=휴, 6/8~10=G, 6/11~12=휴,
//      6/13~14=DS, 6/15=S, 6/16=휴, 6/17~19=D, 6/20~21=휴,
//      6/22~23=D, 6/24=휴, 6/25~28=G
const List<ShiftType> _cCycle = [
  ShiftType.OFF, // 0  → 6/1
  ShiftType.S,   // 1  → 6/2
  ShiftType.S,   // 2  → 6/3
  ShiftType.S,   // 3  → 6/4
  ShiftType.S,   // 4  → 6/5
  ShiftType.OFF, // 5  → 6/6
  ShiftType.OFF, // 6  → 6/7
  ShiftType.G,   // 7  → 6/8
  ShiftType.G,   // 8  → 6/9
  ShiftType.G,   // 9  → 6/10
  ShiftType.OFF, // 10 → 6/11
  ShiftType.OFF, // 11 → 6/12
  ShiftType.DS,  // 12 → 6/13
  ShiftType.DS,  // 13 → 6/14
  ShiftType.S,   // 14 → DS,DS 다음 S
  ShiftType.OFF, // 15 → 6/16
  ShiftType.D,   // 16 → 6/17
  ShiftType.D,   // 17 → 6/18
  ShiftType.D,   // 18 → 6/19
  ShiftType.OFF, // 19 → 6/20
  ShiftType.OFF, // 20 → 6/21
  ShiftType.D,   // 21 → 6/22
  ShiftType.D,   // 22 → 6/23
  ShiftType.OFF, // 23 → 6/24
  ShiftType.G,   // 24 → 6/25
  ShiftType.G,   // 25 → 6/26
  ShiftType.G,   // 26 → 6/27
  ShiftType.G,   // 27 → 6/28
];

// D조: 6/1~2=D, 6/3=휴, 6/4~7=G, 6/8=휴, 6/9~12=S,
//      6/13~14=휴, 6/15~17=G, 6/18~19=휴, 6/20~21=DS,
//      6/22=S, 6/23=휴, 6/24~26=D, 6/27~28=휴
const List<ShiftType> _dCycle = [
  ShiftType.D,   // 0  → 6/1
  ShiftType.D,   // 1  → 6/2
  ShiftType.OFF, // 2  → 6/3
  ShiftType.G,   // 3  → 6/4
  ShiftType.G,   // 4  → 6/5
  ShiftType.G,   // 5  → 6/6
  ShiftType.G,   // 6  → 6/7
  ShiftType.OFF, // 7  → 6/8
  ShiftType.S,   // 8  → 6/9
  ShiftType.S,   // 9  → 6/10
  ShiftType.S,   // 10 → 6/11
  ShiftType.S,   // 11 → 6/12
  ShiftType.OFF, // 12 → 6/13
  ShiftType.OFF, // 13 → 6/14
  ShiftType.G,   // 14 → 6/15
  ShiftType.G,   // 15 → 6/16
  ShiftType.G,   // 16 → 6/17
  ShiftType.OFF, // 17 → 6/18
  ShiftType.OFF, // 18 → 6/19
  ShiftType.DS,  // 19 → 6/20
  ShiftType.DS,  // 20 → 6/21
  ShiftType.S,   // 21 → 6/22
  ShiftType.OFF, // 22 → 6/23
  ShiftType.D,   // 23 → 6/24
  ShiftType.D,   // 24 → 6/25
  ShiftType.D,   // 25 → 6/26
  ShiftType.OFF, // 26 → 6/27
  ShiftType.OFF, // 27 → 6/28
];

final DateTime _baseDate = DateTime(2026, 6, 1);

const Map<String, List<ShiftType>> _teamCycles = {
  'A': _aCycle,
  'B': _bCycle,
  'C': _cCycle,
  'D': _dCycle,
};

class ShiftCalculator {
  // 수동 변경(override) 저장소: 'yyyy-MM-dd' → ShiftType
  // getShift가 참조하도록 메모리에 로드해둠 (loadOverrides로 채움)
  static Map<String, ShiftType> _overrides = {};

  static String _overrideKey(String team, DateTime d) =>
      '${team}_${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 앱 시작 시 SharedPreferences에서 override 목록을 메모리로 로드
  static void setOverrides(Map<String, ShiftType> overrides) {
    _overrides = overrides;
  }

  static Map<String, ShiftType> get overrides => _overrides;

  static bool hasOverride(String team, DateTime date) =>
      _overrides.containsKey(_overrideKey(team, date));

  static ShiftType getShift(String team, DateTime date) {
    // 수동 변경한 날이면 그 값을 우선 (해당 조 + 그 날짜만 적용)
    final ov = _overrides[_overrideKey(team, date)];
    if (ov != null) return ov;

    final cycle = _teamCycles[team] ?? _bCycle;
    final diff = date.difference(_baseDate).inDays;
    final idx = (diff % 28 + 28) % 28;
    return cycle[idx];
  }

  // 사이클 계산값(override 무시) — "원래 근무"를 알아야 할 때 사용
  static ShiftType getCycleShift(String team, DateTime date) {
    final cycle = _teamCycles[team] ?? _bCycle;
    final diff = date.difference(_baseDate).inDays;
    final idx = (diff % 28 + 28) % 28;
    return cycle[idx];
  }

  static Map<String, ShiftType> getAllTeams(DateTime date) {
    return {
      'A': getShift('A', date),
      'B': getShift('B', date),
      'C': getShift('C', date),
      'D': getShift('D', date),
    };
  }

  static List<ShiftType> getMonthShifts(String team, int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return List.generate(daysInMonth, (i) {
      return getShift(team, DateTime(year, month, i + 1));
    });
  }

  static Map<String, int> getMonthStats(String team, int year, int month) {
    final shifts = getMonthShifts(team, year, month);
    return {
      'total': shifts.where((s) => s.isWork).length,
      'D':   shifts.where((s) => s == ShiftType.D).length,
      'G':   shifts.where((s) => s == ShiftType.G).length,
      'S':   shifts.where((s) => s == ShiftType.S).length,
      'DS':  shifts.where((s) => s == ShiftType.DS).length,
      'OFF': shifts.where((s) => s == ShiftType.OFF).length,
    };
  }

  static int getRemainingWorkDays(String team, DateTime today) {
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    int count = 0;
    for (int d = today.day; d <= daysInMonth; d++) {
      final s = getShift(team, DateTime(today.year, today.month, d));
      if (s.isWork) count++;
    }
    return count;
  }

  static List<MapEntry<DateTime, ShiftType>> getUpcoming(
      String team, DateTime from, int days) {
    final result = <MapEntry<DateTime, ShiftType>>[];
    for (int i = 1; i <= days; i++) {
      final d = from.add(Duration(days: i));
      result.add(MapEntry(d, getShift(team, d)));
    }
    return result;
  }
}
