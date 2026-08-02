import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/holiday_service.dart';

class SettingsScreen extends StatefulWidget {
  final String myTeam;
  final ValueChanged<String> onTeamChanged;

  const SettingsScreen({
    super.key,
    required this.myTeam,
    required this.onTeamChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _alarmChannel = MethodChannel('com.example.cspi/alarm');

  bool _alarmEnabled = true;

  // 패턴별 기상 시간
  TimeOfDay _alarmD  = const TimeOfDay(hour: 6,  minute: 30);
  TimeOfDay _alarmS  = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _alarmG  = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _alarmDS = const TimeOfDay(hour: 6,  minute: 30);

  // 알람음 관련
  bool _soundOn = true;
  bool _vibrateOn = true;
  double _volume = 1.0;
  String? _ringtoneUri;   // null이면 기본 알람음
  String _ringtoneName = '기본 알람음';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }


  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alarmEnabled = prefs.getBool('alarm_enabled') ?? true;
      _alarmD  = TimeOfDay(hour: prefs.getInt('alarm_d_hour')  ?? 6,  minute: prefs.getInt('alarm_d_min')  ?? 30);
      _alarmS  = TimeOfDay(hour: prefs.getInt('alarm_s_hour')  ?? 10, minute: prefs.getInt('alarm_s_min')  ?? 0);
      _alarmG  = TimeOfDay(hour: prefs.getInt('alarm_g_hour')  ?? 21, minute: prefs.getInt('alarm_g_min')  ?? 0);
      _alarmDS = TimeOfDay(hour: prefs.getInt('alarm_ds_hour') ?? 6,  minute: prefs.getInt('alarm_ds_min') ?? 30);
      _soundOn = prefs.getBool('alarm_sound_on') ?? true;
      _vibrateOn = prefs.getBool('alarm_vibrate_on') ?? true;
      _volume = prefs.getDouble('alarm_volume') ?? 1.0;
      _ringtoneUri = prefs.getString('alarm_ringtone_uri');
    });
    _refreshRingtoneName();
  }

  Future<void> _refreshRingtoneName() async {
    try {
      final name = await _alarmChannel.invokeMethod<String>(
        'getRingtoneName', {'uri': _ringtoneUri ?? ''});
      if (mounted) setState(() => _ringtoneName = name ?? '기본 알람음');
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_enabled', _alarmEnabled);
    await prefs.setInt('alarm_d_hour',  _alarmD.hour);
    await prefs.setInt('alarm_d_min',   _alarmD.minute);
    await prefs.setInt('alarm_s_hour',  _alarmS.hour);
    await prefs.setInt('alarm_s_min',   _alarmS.minute);
    await prefs.setInt('alarm_g_hour',  _alarmG.hour);
    await prefs.setInt('alarm_g_min',   _alarmG.minute);
    await prefs.setInt('alarm_ds_hour', _alarmDS.hour);
    await prefs.setInt('alarm_ds_min',  _alarmDS.minute);
    await prefs.setBool('alarm_sound_on', _soundOn);
    await prefs.setBool('alarm_vibrate_on', _vibrateOn);
    await prefs.setDouble('alarm_volume', _volume);
    if (_ringtoneUri != null) {
      await prefs.setString('alarm_ringtone_uri', _ringtoneUri!);
    } else {
      await prefs.remove('alarm_ringtone_uri');
    }

    // 저장 직후 네이티브에 실제 알람 등록/해제 요청
    try {
      if (_alarmEnabled) {
        // 정확한 알람 권한이 있는지 확인 (Android 12+)
        final canSchedule = await _alarmChannel.invokeMethod<bool>('canScheduleExactAlarms') ?? true;
        if (!canSchedule && mounted) {
          final goSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('정확한 알람 권한 필요'),
              content: const Text('기상 알람이 정시에 울리려면 "정확한 알람" 권한이 필요해요. 설정 화면으로 이동할까요?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('나중에')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('설정으로 이동')),
              ],
            ),
          );
          if (goSettings == true) {
            await _alarmChannel.invokeMethod('openExactAlarmSettings');
          }
        }
        await _alarmChannel.invokeMethod('scheduleDailyAlarm');
      } else {
        await _alarmChannel.invokeMethod('cancelDailyAlarm');
      }
    } catch (_) {
      // 네이티브 채널 호출 실패 시 무시 (구버전 호환)
    }
  }

  Future<void> _pickRingtone() async {
    try {
      final uri = await _alarmChannel.invokeMethod<String>(
        'pickRingtone', {'current': _ringtoneUri ?? ''});
      // uri가 null이면 취소한 것 → 변경 없음
      if (uri != null) {
        setState(() => _ringtoneUri = uri.isEmpty ? null : uri);
        await _savePrefs();
        await _refreshRingtoneName();
      }
    } catch (_) {}
  }

  Future<void> _pickTime(String shift, TimeOfDay current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: '$shift 패턴 기상 시간',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      switch (shift) {
        case 'D':  _alarmD  = picked; break;
        case 'S':  _alarmS  = picked; break;
        case 'G':  _alarmG  = picked; break;
        case 'DS': _alarmDS = picked; break;
      }
    });
    await _savePrefs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$shift 패턴 알람: ${picked.format(context)} 로 설정됐어요'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text('설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),

              // 내 조 선택
              _SectionLabel(label: '내 조 선택'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: ['A', 'B', 'C', 'D'].map((team) {
                  final isSelected = team == widget.myTeam;
                  return GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('my_team', team);
                      widget.onTeamChanged(team);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE6F1FB) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF378ADD) : const Color(0xFFE0E0E0),
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text('$team조',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: isSelected ? const Color(0xFF185FA5) : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 기상 알람 설정
              _SectionLabel(label: '기상 알람'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                _SwitchRow(
                  label: '자동 기상 알람',
                  value: _alarmEnabled,
                  onChanged: (v) async {
                    setState(() => _alarmEnabled = v);
                    await _savePrefs();
                  },
                ),
              ]),
              const SizedBox(height: 10),

              if (_alarmEnabled) ...[
                _SettingsCard(children: [
                  _AlarmTimeRow(
                    shift: 'D',
                    label: '주간 근무 기상 시간',
                    subtitle: '08:00–15:00 근무',
                    color: const Color(0xFFFAC775),
                    textColor: const Color(0xFF412402),
                    time: _alarmD,
                    onTap: () => _pickTime('D', _alarmD),
                  ),
                  const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0F0F0)),
                  _AlarmTimeRow(
                    shift: 'S',
                    label: '저녁 근무 기상 시간',
                    subtitle: '15:00–22:00 근무',
                    color: const Color(0xFF888780),
                    textColor: const Color(0xFFF1EFE8),
                    time: _alarmS,
                    onTap: () => _pickTime('S', _alarmS),
                  ),
                  const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0F0F0)),
                  _AlarmTimeRow(
                    shift: 'G',
                    label: '야간 근무 기상 시간',
                    subtitle: '22:00–08:00 근무',
                    color: const Color(0xFF2C2C2A),
                    textColor: const Color(0xFFD3D1C7),
                    time: _alarmG,
                    onTap: () => _pickTime('G', _alarmG),
                  ),
                  const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0F0F0)),
                  _AlarmTimeRow(
                    shift: 'DS',
                    label: '주간+저녁 기상 시간',
                    subtitle: '08:00–22:00 근무',
                    color: const Color(0xFF378ADD),
                    textColor: const Color(0xFFE6F1FB),
                    time: _alarmDS,
                    onTap: () => _pickTime('DS', _alarmDS),
                  ),
                ]),
                const SizedBox(height: 24),

                // 알람음 설정
                _SectionLabel(label: '알람음'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SwitchRow(
                    label: '알람음',
                    subtitle: '알람이 울릴 때 소리 재생',
                    value: _soundOn,
                    onChanged: (v) async {
                      setState(() => _soundOn = v);
                      await _savePrefs();
                    },
                  ),
                  if (_soundOn)
                    _NavRow(
                      label: '벨소리',
                      value: _ringtoneName,
                      onTap: _pickRingtone,
                    ),
                  _SwitchRow(
                    label: '진동',
                    subtitle: '알람이 울릴 때 진동',
                    value: _vibrateOn,
                    onChanged: (v) async {
                      setState(() => _vibrateOn = v);
                      await _savePrefs();
                    },
                  ),
                ]),
                if (_soundOn) ...[
                  const SizedBox(height: 12),
                  _SettingsCard(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          const Text('볼륨', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Slider(
                              value: _volume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              label: '${(_volume * 100).round()}%',
                              onChanged: (v) => setState(() => _volume = v),
                              onChangeEnd: (v) async {
                                setState(() => _volume = v);
                                await _savePrefs();
                              },
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text('${(_volume * 100).round()}%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF888780))),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 20),
              ],

              // 홈 위젯 설정
              _SectionLabel(label: '홈 위젯'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                _NavRow(label: '위젯 테마', value: '시스템 따라가기'),
              ]),
              const SizedBox(height: 20),

              // 공휴일
              _SectionLabel(label: '공휴일'),
              const SizedBox(height: 8),
              _SettingsCard(children: [_RefreshHolidayRow()]),
              const SizedBox(height: 20),

              // 앱 정보
              _SectionLabel(label: '정보'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                const _NavRow(label: '버전', value: '1.0.0'),
              ]),
              const SizedBox(height: 32),

              // Made by Roy
              const Center(
                child: Column(
                  children: [
                    Text(
                      'Made by Roy',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Assisted by Weirdo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlarmTimeRow extends StatelessWidget {
  final String shift;
  final String label;
  final String subtitle;
  final Color color;
  final Color textColor;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _AlarmTimeRow({
    required this.shift, required this.label, required this.subtitle,
    required this.color, required this.textColor,
    required this.time, required this.onTap,
  });

  String _fmt() {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(shift,
                  style: TextStyle(fontSize: shift == 'DS' ? 9 : 11,
                    fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                ],
              ),
            ),
            Text(_fmt(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF378ADD))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF888780)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: Color(0xFF888780), letterSpacing: 0.8)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.label, this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
            ],
          )),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: const Color(0xFF378ADD)),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _NavRow({required this.label, required this.value, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF888780)),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF888780)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RefreshHolidayRow extends StatefulWidget {
  @override
  State<_RefreshHolidayRow> createState() => _RefreshHolidayRowState();
}

class _RefreshHolidayRowState extends State<_RefreshHolidayRow> {
  bool _loading = false;
  String _status = '자동 업데이트 (공공 API)';

  Future<void> _refresh() async {
    setState(() { _loading = true; _status = '업데이트 중...'; });
    try {
      final now = DateTime.now();
      await HolidayService.refresh(now.year);
      await HolidayService.refresh(now.year + 1);
      setState(() => _status = '업데이트 완료 ✓');
    } catch (e) {
      setState(() => _status = '실패 (네트워크 확인)');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('공휴일 데이터 새로고침',
                style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 2),
              Text(_status, style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
            ],
          )),
          _loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : GestureDetector(
                onTap: _refresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F1FB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('새로고침',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: Color(0xFF185FA5))),
                ),
              ),
        ],
      ),
    );
  }
}
