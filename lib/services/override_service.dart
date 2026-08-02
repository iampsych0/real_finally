import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'shift_calculator.dart';

/// 사용자가 수동 변경한 근무(override)를 저장/로드한다.
/// 저장 형식: SharedPreferences 'shift_overrides' = JSON { "2026-08-05": "G", ... }
/// 네이티브(위젯/알람)도 읽을 수 있게 shared_preferences 기본 키를 쓴다.
class OverrideService {
  static const _key = 'shift_overrides_v2';

  /// 앱 시작 시 호출 — 저장된 override를 ShiftCalculator 메모리로 로드
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final map = <String, ShiftType>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((date, val) {
          map[date] = shiftTypeFromKey(val as String);
        });
      } catch (_) {}
    }
    ShiftCalculator.setOverrides(map);
  }

  /// 특정 조의 특정 날짜 근무를 수동 설정하고 저장
  static Future<void> setOverride(String team, DateTime date, ShiftType shift) async {
    final map = Map<String, ShiftType>.from(ShiftCalculator.overrides);
    map[_overrideKey(team, date)] = shift;
    ShiftCalculator.setOverrides(map);
    await _persist(map);
  }

  /// 수동 설정 해제 (사이클 자동 계산으로 되돌림)
  static Future<void> clearOverride(String team, DateTime date) async {
    final map = Map<String, ShiftType>.from(ShiftCalculator.overrides);
    map.remove(_overrideKey(team, date));
    ShiftCalculator.setOverrides(map);
    await _persist(map);
  }

  static Future<void> _persist(Map<String, ShiftType> map) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, String>{};
    map.forEach((key, shift) {
      encoded[key] = shiftTypeToKey(shift);
    });
    await prefs.setString(_key, jsonEncode(encoded));
  }

  static String _overrideKey(String team, DateTime d) =>
      '${team}_${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
