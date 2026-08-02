import 'package:flutter/material.dart';
import 'shift_calculator.dart';

class ShiftColors {
  static const Color dayBg     = Color(0xFFFAC775);
  static const Color dayText   = Color(0xFF412402);
  static const Color nightBg   = Color(0xFF2C2C2A);
  static const Color nightText = Color(0xFFD3D1C7);
  static const Color evenBg    = Color(0xFF888780);
  static const Color evenText  = Color(0xFFF1EFE8);
  static const Color dsBg      = Color(0xFF378ADD);
  static const Color dsText    = Color(0xFFE6F1FB);
  static const Color offColor  = Color(0xFFE24B4A);

  static const Color todayBlue = Color(0xFF378ADD);
  static const Color myTeamBg  = Color(0xFFEAF3DE);
  static const Color myTeamText= Color(0xFF27500A);

  static Color bgFor(ShiftType t) {
    switch (t) {
      case ShiftType.D:   return dayBg;
      case ShiftType.G:   return nightBg;
      case ShiftType.S:   return evenBg;
      case ShiftType.DS:  return dsBg;
      case ShiftType.OFF: return Colors.transparent;
    }
  }

  static Color textFor(ShiftType t) {
    switch (t) {
      case ShiftType.D:   return dayText;
      case ShiftType.G:   return nightText;
      case ShiftType.S:   return evenText;
      case ShiftType.DS:  return dsText;
      case ShiftType.OFF: return offColor;
    }
  }
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF378ADD),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF378ADD),
      unselectedItemColor: Color(0xFF888780),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
