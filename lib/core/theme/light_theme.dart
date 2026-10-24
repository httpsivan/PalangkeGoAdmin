import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_extensions.dart';

ThemeData buildLightTheme() {
  const primary = Color(0xFF0F4A3C);
  const text = Color(0xFF1F2937);
  final base = ThemeData.light(useMaterial3: true);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
  );

  return base.copyWith(
    brightness: Brightness.light,
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    canvasColor: const Color(0xFFF8FAFC),
    cardColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: text,
      outline: const Color(0xFFE2E8F0),
      error: const Color(0xFFEF4444),
    ),
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: text, displayColor: text),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      labelStyle: const TextStyle(color: text),
      floatingLabelStyle: const TextStyle(color: primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    ),
    dividerColor: const Color(0xFFE2E8F0),
    dividerTheme: const DividerThemeData(color: Color(0xFFE2E8F0), space: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      textStyle: GoogleFonts.inter(color: text, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
        shadowColor:
            WidgetStatePropertyAll(Colors.black.withValues(alpha: .14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: primary,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      titleTextStyle: GoogleFonts.inter(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: GoogleFonts.inter(color: text, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF161D1B),
        borderRadius: BorderRadius.circular(7),
      ),
      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: const WidgetStatePropertyAll(Color(0xFF94A3B8)),
      trackColor: const WidgetStatePropertyAll(Color(0xFFE2E8F0)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(7),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: GoogleFonts.inter(
        color: const Color(0xFF475569),
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      dataTextStyle: GoogleFonts.inter(color: text, fontSize: 13),
      dividerThickness: 1,
    ),
    extensions: const [
      AppSemanticColors(
        pageBackground: Color(0xFFF8FAFC),
        navigationBackground: primary,
        navigationHover: Color(0x24FFFFFF),
        navigationControl: Color(0x1FFFFFFF),
        activeNavigation: Colors.white,
        activeNavigationText: Color(0xFF073E32),
        borderOnHero: Color(0x2EFFFFFF),
        cardBackground: Colors.white,
        elevatedSurface: Colors.white,
        inputSurface: Colors.white,
        modalSurface: Colors.white,
        selectedSurface: Color(0xFFECFDF5),
        primaryText: text,
        secondaryText: Color(0xFF475569),
        disabledText: Color(0xFF94A3B8),
        accent: primary,
        accentStrong: Color(0xFF10B981),
        accentDark: primary,
        divider: Color(0xFFE2E8F0),
        success: Color(0xFF10B981),
        successContainer: Color(0xFFECFDF5),
        warning: Color(0xFFF59E0B),
        warningContainer: Color(0xFFFFFBEB),
        danger: Color(0xFFEF4444),
        dangerContainer: Color(0xFFFEF2F2),
        info: Color(0xFF2563EB),
        infoContainer: Color(0xFFEFF6FF),
        mutedText: Color(0xFF9CA3AF),
        subtleBorder: Color(0xFFE2E8F0),
        tableHeader: Color(0xFFF1F5F9),
        hoverSurface: Color(0xFFF8FAFC),
        overlayScrim: Color(0x80031E18),
        heroBackground: primary,
        heroForeground: Colors.white,
        heroMuted: Color(0xB3FFFFFF),
      ),
    ],
  );
}
