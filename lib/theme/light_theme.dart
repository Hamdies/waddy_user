import 'package:flutter/material.dart';
import 'package:sixam_mart/util/app_constants.dart';

ThemeData light() => ThemeData(
  fontFamily: AppConstants.fontFamily,
  primaryColor: const Color(0xFF0C3C3A), // dark green/teal background (#0C3C3A)
  secondaryHeaderColor: const Color(0xFF00F28D), // neon green accent (#00F28D)
  disabledColor: const Color(0xFFB0B0B0),
  brightness: Brightness.light,
  hintColor: Colors.grey[500],
  cardColor: Colors.white,
  shadowColor: Colors.black.withValues(alpha: 0.04),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: const Color(0xFF00F28D)),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF0C3C3A), // primary dark
    secondary: Color(0xFF00F28D), // accent neon
    surface: Colors.white,
    background: Color(0xFFFDFDFD),
    error: Color(0xFFE84D4F),
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.white,
  ),
  dialogTheme: const DialogThemeData(surfaceTintColor: Colors.white),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: const Color(0xFF00F28D), // accent for FAB
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
  ),
  bottomAppBarTheme: const BottomAppBarThemeData(
    surfaceTintColor: Colors.white,
    height: 60,
    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    color: Color(0xFF0C3C3A), // dark primary for bottom bar
  ),
  dividerTheme: DividerThemeData(
    thickness: 0.5,
    color: Colors.grey.withOpacity(0.3),
  ),
  tabBarTheme: const TabBarThemeData(
    indicatorColor: Color(0xFF00F28D), // accent indicator
    labelColor: Color(0xFF00F28D),
    unselectedLabelColor: Colors.grey,
    dividerColor: Colors.transparent,
  ),
);
