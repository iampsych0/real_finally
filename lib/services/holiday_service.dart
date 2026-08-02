import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

class HolidayService {
  static const String _serviceKey =
      '1fa7dc1afde7ca30d8ddff3c3fa8b8e460dfbe26d4acdee3dbafb9c7c0504418';

  static const String _baseUrl =
      'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo';

  static final Map<int, Map<String, String>> _memCache = {};

  /// 앱 시작 시 올해 + 내년 미리 로드 (백그라운드)
  static Future<void> preload() async {
    final now = DateTime.now();
    await Future.wait([
      loadYear(now.year),
      loadYear(now.year + 1),
    ]);
  }

  /// 특정 연도 공휴일 로드
  static Future<Map<String, String>> loadYear(int year) async {
    if (_memCache.containsKey(year)) return _memCache[year]!;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('holidays_v2_$year');
    if (cached != null) {
      final map = Map<String, String>.from(jsonDecode(cached));
      _memCache[year] = map;
      return map;
    }

    try {
      final map = await _fetchFromApi(year);
      await prefs.setString('holidays_v2_$year', jsonEncode(map));
      _memCache[year] = map;
      return map;
    } catch (e) {
      final fallback = _hardcodedFallback[year] ?? {};
      _memCache[year] = fallback;
      return fallback;
    }
  }

  /// 캐시 강제 갱신 (설정 화면 새로고침 버튼)
  static Future<void> refresh(int year) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('holidays_v2_$year');
    _memCache.remove(year);
    await loadYear(year);
  }

  /// 날짜 공휴일 이름 반환 (동기 - 메모리 캐시)
  static String? getHolidayName(DateTime date) {
    final yearData = _memCache[date.year];
    if (yearData == null) return null;
    return yearData[_dateKey(date)];
  }

  static bool isHoliday(DateTime date) => getHolidayName(date) != null;

  /// 해당 월 공휴일 맵 {day: name}
  static Map<int, String> getMonthHolidays(int year, int month) {
    final yearData = _memCache[year] ?? _hardcodedFallback[year] ?? {};
    final result = <int, String>{};
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final key =
          '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      if (yearData.containsKey(key)) result[d] = yearData[key]!;
    }
    return result;
  }

  // ── API 호출 (XML 파싱) ────────────────────────────────────────
  static Future<Map<String, String>> _fetchFromApi(int year) async {
    final result = <String, String>{};

    for (int month = 1; month <= 12; month++) {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'serviceKey': _serviceKey,
        'solYear': '$year',
        'solMonth': month.toString().padLeft(2, '0'),
        'numOfRows': '20',
        'pageNo': '1',
      });

      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) continue;

      // XML 파싱
      try {
        // response.body는 Latin-1로 디코딩되어 한글이 깨지므로
        // bodyBytes를 UTF-8로 직접 디코딩
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final document = XmlDocument.parse(decodedBody);
        final items = document.findAllElements('item');

        for (final item in items) {
          final locdate = item.findElements('locdate').firstOrNull?.innerText;
          final dateName = item.findElements('dateName').firstOrNull?.innerText;
          final isHoliday = item.findElements('isHoliday').firstOrNull?.innerText;

          if (locdate == null || dateName == null || isHoliday != 'Y') continue;
          if (locdate.length != 8) continue;

          // "20260101" → "2026-01-01"
          final dateKey =
              '${locdate.substring(0, 4)}-${locdate.substring(4, 6)}-${locdate.substring(6, 8)}';
          result[dateKey] = dateName;
        }
      } catch (_) {
        continue;
      }
    }

    return result;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── 하드코딩 Fallback ──────────────────────────────────────────
  static const Map<int, Map<String, String>> _hardcodedFallback = {
    2025: {
      '2025-01-01': '신정',
      '2025-01-28': '설날 연휴',
      '2025-01-29': '설날',
      '2025-01-30': '설날 연휴',
      '2025-03-01': '삼일절',
      '2025-05-05': '어린이날',
      '2025-05-06': '어린이날 대체',
      '2025-06-06': '현충일',
      '2025-08-15': '광복절',
      '2025-10-03': '개천절',
      '2025-10-05': '추석 연휴',
      '2025-10-06': '추석',
      '2025-10-07': '추석 연휴',
      '2025-10-08': '추석 대체',
      '2025-10-09': '한글날',
      '2025-12-25': '크리스마스',
    },
    2026: {
      '2026-01-01': '신정',
      '2026-02-16': '설날 연휴',
      '2026-02-17': '설날',
      '2026-02-18': '설날 연휴',
      '2026-03-01': '삼일절',
      '2026-03-02': '삼일절 대체',
      '2026-05-01': '노동절',
      '2026-05-05': '어린이날',
      '2026-05-24': '부처님오신날',
      '2026-05-25': '부처님오신날 대체',
      '2026-06-03': '전국동시지방선거',
      '2026-06-06': '현충일',
      '2026-07-17': '제헌절',
      '2026-08-15': '광복절',
      '2026-08-16': '광복절 대체',
      '2026-09-24': '추석 연휴',
      '2026-09-25': '추석',
      '2026-09-26': '추석 연휴',
      '2026-10-03': '개천절',
      '2026-10-09': '한글날',
      '2026-12-25': '크리스마스',
    },
    2027: {
      '2027-01-01': '신정',
      '2027-02-06': '설날 연휴',
      '2027-02-07': '설날',
      '2027-02-08': '설날 연휴',
      '2027-03-01': '삼일절',
      '2027-05-01': '노동절',
      '2027-05-05': '어린이날',
      '2027-05-13': '부처님오신날',
      '2027-06-06': '현충일',
      '2027-07-17': '제헌절',
      '2027-08-15': '광복절',
      '2027-09-14': '추석 연휴',
      '2027-09-15': '추석',
      '2027-09-16': '추석 연휴',
      '2027-10-03': '개천절',
      '2027-10-09': '한글날',
      '2027-12-25': '크리스마스',
    },
  };
}
