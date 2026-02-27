import 'package:flutter/material.dart';
import 'package:sixam_mart/util/app_constants.dart';

ThemeData light() => ThemeData(
  fontFamily: AppConstants.fontFamily,
  primaryColor: const Color(
    0xFF134E4A,
  ), // dark teal background from brand image
  secondaryHeaderColor: const Color(
    0xFF1EF2A0,
  ), // bright neon green accent from brand image
  disabledColor: const Color(0xFFB0B0B0),
  brightness: Brightness.light,
  hintColor: Colors.grey[500],
  cardColor: Colors.white,
  shadowColor: Colors.black.withValues(alpha: 0.04),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: const Color(0xFF1EF2A0)),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF134E4A), // primary dark teal
    secondary: Color(0xFF1EF2A0), // accent neon green
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
    backgroundColor: const Color(0xFF1EF2A0), // neon green accent for FAB
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
  ),
  bottomAppBarTheme: const BottomAppBarThemeData(
    surfaceTintColor: Colors.white,
    height: 60,
    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    color: Color(0xFF134E4A), // dark teal for bottom bar
  ),
  dividerTheme: DividerThemeData(
    thickness: 0.5,
    color: Colors.grey.withOpacity(0.3),
  ),
  tabBarTheme: const TabBarThemeData(
    indicatorColor: Color(0xFF1EF2A0), // neon green indicator
    labelColor: Color(0xFF1EF2A0),
    unselectedLabelColor: Colors.grey,
    dividerColor: Colors.transparent,
  ),
);
