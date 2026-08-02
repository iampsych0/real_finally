import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_theme.dart';
import 'services/holiday_service.dart';
import 'services/override_service.dart';
import 'services/shift_calculator.dart';
import 'screens/all_schedule_screen.dart';
import 'screens/my_schedule_screen.dart';
import 'screens/settings_screen.dart';

const _alarmChannel = MethodChannel('com.example.cspi/alarm');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedTeam = prefs.getString('my_team') ?? 'B';

  // 수동 변경한 근무(override)를 메모리로 로드 (근무표/위젯/알람이 참조)
  await OverrideService.load();

  // 앱 시작 시 올해 + 내년 공휴일 백그라운드 로드
  // UI 블로킹 없이 비동기로 실행
  HolidayService.preload();

  // 알람이 켜져 있으면 앱 실행 시마다 자정 트리거 재등록 (안전망)
  final alarmEnabled = prefs.getBool('alarm_enabled') ?? true;
  if (alarmEnabled) {
    try {
      // Android 13+ 알림 권한 요청 (풀스크린 알람 표시에 필요)
      await _alarmChannel.invokeMethod('requestNotificationPermission');
      await _alarmChannel.invokeMethod('scheduleDailyAlarm');
    } catch (_) {}
  }

  runApp(ShiftApp(initialTeam: savedTeam));
}

class ShiftApp extends StatelessWidget {
  final String initialTeam;
  const ShiftApp({super.key, required this.initialTeam});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSPI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: MainShell(initialTeam: initialTeam),
    );
  }
}

class MainShell extends StatefulWidget {
  final String initialTeam;
  const MainShell({super.key, required this.initialTeam});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late String _myTeam;

  @override
  void initState() {
    super.initState();
    _myTeam = widget.initialTeam;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPermissionOnboarding());
  }

  static const _permChannel = MethodChannel('com.example.cspi/alarm');

  // 첫 실행 시 필요한 권한을 순서대로 안내
  Future<void> _runPermissionOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('perm_onboarding_done') ?? false;

    // 1. 알림 권한 - 시스템이 알아서 한 번만 물음
    try {
      await _permChannel.invokeMethod('requestNotificationPermission');
    } catch (_) {}

    if (done) {
      // 온보딩을 이미 했더라도, 정확한 알람 권한이 꺼졌으면 조용히 재확인
      return;
    }

    if (!mounted) return;

    // 2) 정확한 알람 권한
    try {
      final canExact =
          await _permChannel.invokeMethod<bool>('canScheduleExactAlarms') ?? true;
      if (!canExact && mounted) {
        final go = await _askPermissionDialog(
          '정확한 알람 권한',
          '기상 알람이 정시에 울리려면 "알람 및 리마인더" 권한이 필요해요. 설정으로 이동할까요?',
        );
        if (go) await _permChannel.invokeMethod('openExactAlarmSettings');
      }
    } catch (_) {}

    if (!mounted) return;

    // 3) 전체 화면 알림 권한 (Android 14+)
    try {
      final canFull =
          await _permChannel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
      if (!canFull && mounted) {
        final go = await _askPermissionDialog(
          '전체 화면 알림 권한',
          '잠금화면에서 알람 화면이 자동으로 뜨려면 "전체 화면 알림" 권한이 필요해요. '
          '(꺼져 있어도 소리·진동은 울려요.) 설정으로 이동할까요?',
        );
        if (go) await _permChannel.invokeMethod('openFullScreenIntentSettings');
      }
    } catch (_) {}

    await prefs.setBool('perm_onboarding_done', true);
  }

  Future<bool> _askPermissionDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('나중에')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('설정 열기')),
        ],
      ),
    );
    return result ?? false;
  }

  void _onTeamChanged(String team) => setState(() => _myTeam = team);

  @override
  Widget build(BuildContext context) {
    final screens = [
      AllScheduleScreen(myTeam: _myTeam),
      MyScheduleScreen(myTeam: _myTeam),
      SettingsScreen(myTeam: _myTeam, onTeamChanged: _onTeamChanged),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: '전체 근무표',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '내 근무',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
