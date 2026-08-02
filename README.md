# 교대근무 스케줄 앱

4조3교대 전용 Android 앱 + 홈 위젯

---

## 기술 스택
- Flutter 3.x
- shared_preferences (조/설정 저장)
- flutter_local_notifications (알림)
- home_widget (홈 위젯 연동)
- Android 네이티브 AppWidgetProvider (Kotlin)

---

## 프로젝트 구조

```
lib/
├── main.dart                        ← 앱 진입점, 하단탭
├── services/
│   ├── shift_calculator.dart        ← 28일 사이클 계산 엔진
│   └── app_theme.dart               ← 색상, 테마 상수
├── widgets/
│   ├── shift_badge.dart             ← D/G/S/DS/휴 뱃지
│   └── today_banner.dart            ← 오늘 근무 배너
└── screens/
    ├── all_schedule_screen.dart     ← 전체 근무표 (4조 캘린더)
    ├── my_schedule_screen.dart      ← 내 근무 (이번주+통계+일정)
    └── settings_screen.dart         ← 설정 (조선택, 알림, 위젯)

android_widget/
├── ShiftWidgetProvider.kt           ← 홈 위젯 로직
└── widget_layout.xml                ← 위젯 UI 레이아웃
```

---

## 설치 방법

### 1. Flutter 환경 준비
```powershell
# Flutter SDK 설치 후
flutter doctor   # ✓ Flutter ✓ Android toolchain 확인
```

### 2. 프로젝트 생성 및 코드 복사
```powershell
flutter create shift_schedule
cd shift_schedule
# lib/ 아래 파일들 복사
# pubspec.yaml 교체
```

### 3. 의존성 설치
```powershell
flutter pub get
```

### 4. Android 위젯 설정
```
android/app/src/main/java/.../ShiftWidgetProvider.kt 위치에 복사
android/app/src/main/res/layout/widget_layout.xml 복사
android/app/src/main/AndroidManifest.xml 에 receiver 등록:

<receiver android:name=".ShiftWidgetProvider"
    android:exported="true">
  <intent-filter>
    <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
  </intent-filter>
  <meta-data
      android:name="android.appwidget.provider"
      android:resource="@xml/widget_info"/>
</receiver>
```

### 5. APK 빌드
```powershell
flutter build apk --release
# 결과물: build/app/outputs/flutter-apk/app-release.apk
```

### 6. 폰에 설치
```
1. 설정 → 보안 → 출처를 알 수 없는 앱 허용
2. USB로 폰에 .apk 전송
3. 파일 관리자로 .apk 실행 → 설치
```

---

## 교대 사이클 (28일 주기)

기준일: **2026년 6월 1일 = 각 조 사이클 idx 0** (6월 실제 근무표로 검증 완료)

각 조는 독립된 28일 사이클 배열을 사용한다 (`shift_calculator.dart` / `ShiftWidgetProvider.kt` 두 곳에 동일하게 정의 — 사이클 변경 시 반드시 둘 다 수정).

```
A조: S-휴-D-D-D-휴-휴-D-D-휴-G-G-G-G-휴-S-S-S-S-휴-휴-G-G-G-휴-휴-DS-DS
B조: G-G-G-휴-휴-DS-DS-S-휴-D-D-D-휴-휴-D-D-휴-G-G-G-G-휴-S-S-S-S-휴-휴
C조: 휴-S-S-S-S-휴-휴-G-G-G-휴-휴-DS-DS-S-휴-D-D-D-휴-휴-D-D-휴-G-G-G-G
D조: D-D-휴-G-G-G-G-휴-S-S-S-S-휴-휴-G-G-G-휴-휴-DS-DS-S-휴-D-D-D-휴-휴
```

---

## 근무 유형

| 기호 | 색상     | 의미       | 시간           |
|------|----------|------------|----------------|
| D    | 노란원   | 주간       | 08:00-15:00    |
| G    | 검정원   | 야간       | 22:00-08:00    |
| S    | 회색원   | 저녁       | 15:00-22:00    |
| DS   | 파란원   | 주간+저녁  | 08:00-22:00    |
| 휴   | 빨간글씨 | 휴무       | —              |

---

## 공휴일 API 설정 방법

### 1. 공공데이터포털 가입 및 API 키 발급
```
1. https://www.data.go.kr 접속 → 회원가입
2. 검색창에 "특일정보" 입력
3. "한국천문연구원_특일 정보" 클릭
4. "활용신청" 버튼 클릭 → 승인 (보통 즉시 또는 1~2일)
5. 마이페이지 → 오픈API → "일반 인증키(Decoding)" 복사
```

### 2. 앱에 키 입력
```dart
// lib/services/holiday_service.dart 상단
static const String _serviceKey = '여기에_발급받은_키_붙여넣기';
```

### 3. 동작 방식
```
앱 실행
  └─ HolidayService.preload() 호출 (백그라운드, UI 블로킹 없음)
       ├─ 캐시(SharedPreferences) 있으면 → 즉시 사용
       ├─ 없으면 → API 호출 → 캐시 저장
       └─ API 실패 시 → 하드코딩 데이터 사용 (2025~2027)

설정 → 공휴일 새로고침
  └─ 캐시 삭제 후 API 재호출 (올해 + 내년)
```

### 특징
- 5G/LTE 있으면 어디서나 자동 갱신
- 한 번 받은 데이터는 캐시에 저장 → 다음 실행 시 빠름
- 인터넷 없어도 캐시 또는 fallback으로 동작
- 매년 패치 불필요 — API가 알아서 최신 데이터 제공
