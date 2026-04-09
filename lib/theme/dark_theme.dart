import 'package:flutter/material.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/theme/light_theme.dart';

// ─── Waddy Dark Theme ──────────────────────────────────────────────────────────
// Dark surfaces use teal-tinted near-blacks — avoids the generic blue-gray dark
// Shadows shift warm to add depth without pure black

ThemeData dark({Color color = const Color(0xFF1D706A)}) => ThemeData(
  fontFamily: AppConstants.fontFamily,
  primaryColor: color,
  secondaryHeaderColor: WaddyColors.primary,
  disabledColor: const Color(0xFF5A6360),
  brightness: Brightness.dark,
  hintColor: const Color(0xFF8A9896),
  cardColor: const Color(0xFF1E2926),      // teal-tinted dark card
  shadowColor: const Color(0x33000000),
  scaffoldBackgroundColor: const Color(0xFF111715), // very dark teal-black
  textTheme: const TextTheme(bodyMedium: TextStyle(color: Color(0xFFDDE8E6))),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: WaddyColors.mint),
  ),
  colorScheme: ColorScheme.dark(
    primary:    color,
    secondary:  WaddyColors.mint,
    tertiary:   WaddyColors.coral,
    surface:    const Color(0xFF1E2926),
    error:      const Color(0xFFFF6B6B),
    onPrimary:  Colors.white,
    onSecondary: WaddyColors.primary,
    onTertiary:  Colors.white,
    onSurface:   const Color(0xFFDDE8E6),
    onError:     Colors.white,
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: Color(0xFF243029),
    surfaceTintColor: Color(0xFF243029),
  ),
  dialogTheme: const DialogThemeData(surfaceTintColor: Color(0xFF1E2926)),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: WaddyColors.mint,
    foregroundColor: WaddyColors.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(500)),
  ),
  bottomAppBarTheme: const BottomAppBarThemeData(
    surfaceTintColor: Color(0xFF111715),
    height: 60,
    padding: EdgeInsets.symmetric(vertical: 5),
    color: Color(0xFF111715),
  ),
  dividerTheme: const DividerThemeData(
    thickness: 0.5,
    color: Color(0xFF2A3532),
  ),
  tabBarTheme: const TabBarThemeData(
    indicatorColor: WaddyColors.mint,
    labelColor: WaddyColors.mint,
    unselectedLabelColor: Color(0xFF8A9896),
    dividerColor: Colors.transparent,
  ),
);
