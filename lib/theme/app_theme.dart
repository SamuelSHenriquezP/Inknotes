import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemePreset {
  monochrome,
  sepia,
  midnight,
  forest,
  lavender,
}

extension AppThemePresetExt on AppThemePreset {
  String get label {
    switch (this) {
      case AppThemePreset.monochrome:
        return 'Monocromo';
      case AppThemePreset.sepia:
        return 'Papel Sepia';
      case AppThemePreset.midnight:
        return 'Midnight OLED';
      case AppThemePreset.forest:
        return 'Esmeralda Nórdico';
      case AppThemePreset.lavender:
        return 'Lavanda Pastel';
    }
  }

  String get description {
    switch (this) {
      case AppThemePreset.monochrome:
        return 'Blanco y negro editorial minimalista';
      case AppThemePreset.sepia:
        return 'Tono pergamino cálido descansado';
      case AppThemePreset.midnight:
        return 'Negro profundo para pantallas OLED';
      case AppThemePreset.forest:
        return 'Sensación botánica fresca y serena';
      case AppThemePreset.lavender:
        return 'Toque lila relajante para escribir';
    }
  }

  Color previewColor(bool isDark) {
    switch (this) {
      case AppThemePreset.monochrome:
        return isDark ? const Color(0xFFF4F4F5) : const Color(0xFF111111);
      case AppThemePreset.sepia:
        return isDark ? const Color(0xFFDF9A62) : const Color(0xFF8D4B26);
      case AppThemePreset.midnight:
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
      case AppThemePreset.forest:
        return isDark ? const Color(0xFF34D399) : const Color(0xFF15803D);
      case AppThemePreset.lavender:
        return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    }
  }

  Color bgPrimary(bool isDark) {
    if (!isDark) {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFFF9F9FB);
        case AppThemePreset.sepia:
          return const Color(0xFFF0E4CE);
        case AppThemePreset.midnight:
          return const Color(0xFFE5ECF6);
        case AppThemePreset.forest:
          return const Color(0xFFE3EFE6);
        case AppThemePreset.lavender:
          return const Color(0xFFECE4F7);
      }
    } else {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFF101012);
        case AppThemePreset.sepia:
          return const Color(0xFF1A1410);
        case AppThemePreset.midnight:
          return const Color(0xFF050B14);
        case AppThemePreset.forest:
          return const Color(0xFF09150F);
        case AppThemePreset.lavender:
          return const Color(0xFF130D1F);
      }
    }
  }

  Color surfaceCard(bool isDark) {
    if (!isDark) {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFFFFFFFF);
        case AppThemePreset.sepia:
          return const Color(0xFFFBF4E4);
        case AppThemePreset.midnight:
          return const Color(0xFFF5F8FE);
        case AppThemePreset.forest:
          return const Color(0xFFF4FAF5);
        case AppThemePreset.lavender:
          return const Color(0xFFF9F5FE);
      }
    } else {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFF1C1C1F);
        case AppThemePreset.sepia:
          return const Color(0xFF261E18);
        case AppThemePreset.midnight:
          return const Color(0xFF0F1A2B);
        case AppThemePreset.forest:
          return const Color(0xFF12241B);
        case AppThemePreset.lavender:
          return const Color(0xFF1E1530);
      }
    }
  }

  Color surfaceElevated(bool isDark) {
    if (!isDark) {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFFF1F1F4);
        case AppThemePreset.sepia:
          return const Color(0xFFE8D7BC);
        case AppThemePreset.midnight:
          return const Color(0xFFD8E3F2);
        case AppThemePreset.forest:
          return const Color(0xFFD5E6DA);
        case AppThemePreset.lavender:
          return const Color(0xFFE2D6F3);
      }
    } else {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFF27272B);
        case AppThemePreset.sepia:
          return const Color(0xFF332820);
        case AppThemePreset.midnight:
          return const Color(0xFF182840);
        case AppThemePreset.forest:
          return const Color(0xFF1B3327);
        case AppThemePreset.lavender:
          return const Color(0xFF2B1F43);
      }
    }
  }

  Color textPrimary(bool isDark) {
    if (!isDark) {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFF111111);
        case AppThemePreset.sepia:
          return const Color(0xFF3A281A);
        case AppThemePreset.midnight:
          return const Color(0xFF0E1F38);
        case AppThemePreset.forest:
          return const Color(0xFF12291B);
        case AppThemePreset.lavender:
          return const Color(0xFF24143D);
      }
    } else {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFFF4F4F5);
        case AppThemePreset.sepia:
          return const Color(0xFFF3E7D4);
        case AppThemePreset.midnight:
          return const Color(0xFFE8F1FF);
        case AppThemePreset.forest:
          return const Color(0xFFE4F4EA);
        case AppThemePreset.lavender:
          return const Color(0xFFF1EAFF);
      }
    }
  }

  Color textSecondary(bool isDark) {
    if (!isDark) {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFF666666);
        case AppThemePreset.sepia:
          return const Color(0xFF786350);
        case AppThemePreset.midnight:
          return const Color(0xFF4B6180);
        case AppThemePreset.forest:
          return const Color(0xFF496B55);
        case AppThemePreset.lavender:
          return const Color(0xFF63507D);
      }
    } else {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFFA1A1AA);
        case AppThemePreset.sepia:
          return const Color(0xFFB5A492);
        case AppThemePreset.midnight:
          return const Color(0xFF8CA5C9);
        case AppThemePreset.forest:
          return const Color(0xFF86B098);
        case AppThemePreset.lavender:
          return const Color(0xFFA595C7);
      }
    }
  }

  Color borderSubtle(bool isDark) {
    if (!isDark) {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFFE4E4E7);
        case AppThemePreset.sepia:
          return const Color(0xFFDFCDAE);
        case AppThemePreset.midnight:
          return const Color(0xFFC9D7EB);
        case AppThemePreset.forest:
          return const Color(0xFFC2DBC8);
        case AppThemePreset.lavender:
          return const Color(0xFFD6C6EC);
      }
    } else {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFF27272A);
        case AppThemePreset.sepia:
          return const Color(0xFF3F3228);
        case AppThemePreset.midnight:
          return const Color(0xFF1D304D);
        case AppThemePreset.forest:
          return const Color(0xFF213D2F);
        case AppThemePreset.lavender:
          return const Color(0xFF33254F);
      }
    }
  }

  Color accentColor(bool isDark) {
    if (!isDark) {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFF111111);
        case AppThemePreset.sepia:
          return const Color(0xFF8D4B26);
        case AppThemePreset.midnight:
          return const Color(0xFF1D4ED8);
        case AppThemePreset.forest:
          return const Color(0xFF15803D);
        case AppThemePreset.lavender:
          return const Color(0xFF7C3AED);
      }
    } else {
      switch (this) {
        case AppThemePreset.monochrome:
          return const Color(0xFFF4F4F5);
        case AppThemePreset.sepia:
          return const Color(0xFFDF9A62);
        case AppThemePreset.midnight:
          return const Color(0xFF60A5FA);
        case AppThemePreset.forest:
          return const Color(0xFF34D399);
        case AppThemePreset.lavender:
          return const Color(0xFFA78BFA);
      }
    }
  }

  Color onAccentColor(bool isDark) {
    final accent = accentColor(isDark);
    return ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : const Color(0xFF111111);
  }
}

enum NoteFontFamily {
  jakarta,
  lora,
  jetbrainsMono,
  kalam,
  merriweather,
}

extension NoteFontFamilyExt on NoteFontFamily {
  String get label {
    switch (this) {
      case NoteFontFamily.jakarta:
        return 'Plus Jakarta Sans';
      case NoteFontFamily.lora:
        return 'Lora';
      case NoteFontFamily.jetbrainsMono:
        return 'JetBrains Mono';
      case NoteFontFamily.kalam:
        return 'Kalam';
      case NoteFontFamily.merriweather:
        return 'Merriweather';
    }
  }

  String get category {
    switch (this) {
      case NoteFontFamily.jakarta:
        return 'Moderna & Limpia';
      case NoteFontFamily.lora:
        return 'Serif Literaria';
      case NoteFontFamily.jetbrainsMono:
        return 'Máquina / Código';
      case NoteFontFamily.kalam:
        return 'Manuscrita / Diario';
      case NoteFontFamily.merriweather:
        return 'Lectura Editorial';
    }
  }

  TextStyle textStyle({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    double height = 1.6,
  }) {
    switch (this) {
      case NoteFontFamily.jakarta:
        return GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: height,
        );
      case NoteFontFamily.lora:
        return GoogleFonts.lora(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: height,
        );
      case NoteFontFamily.jetbrainsMono:
        return GoogleFonts.jetBrainsMono(
          fontSize: fontSize * 0.92,
          color: color,
          fontWeight: fontWeight,
          height: height,
        );
      case NoteFontFamily.kalam:
        return GoogleFonts.kalam(
          fontSize: fontSize * 1.08,
          color: color,
          fontWeight: fontWeight,
          height: height,
        );
      case NoteFontFamily.merriweather:
        return GoogleFonts.merriweather(
          fontSize: fontSize * 0.95,
          color: color,
          fontWeight: fontWeight,
          height: height,
        );
    }
  }
}

class AppTheme {
  // Pastel Highlight Colors for Notes
  static const List<Color> highlightColors = [
    Color(0xFFFFE082), // Soft Amber / Yellow
    Color(0xFFA5D6A7), // Soft Sage Mint
    Color(0xFF90CAF9), // Soft Celestial Sky
    Color(0xFFCE93D8), // Soft Pastel Lavender
    Color(0xFFFFAB91), // Soft Warm Peach
  ];

  // Radii
  static const double cardRadius = 16.0;
  static const double pillRadius = 10.0;
  static const double buttonRadius = 10.0;
  static const double sheetRadius = 20.0;

  // Soft UI Shadows
  static List<BoxShadow> getSoftShadow(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.02),
          blurRadius: 1,
          offset: const Offset(0, -1),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.02),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // Backwards compatibility properties (Monochrome defaults)
  static const Color lightBgPrimary = Color(0xFFFAFAFA);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF111111);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color lightBorderSubtle = Color(0xFFE4E4E7);

  static const Color darkBgPrimary = Color(0xFF121212);
  static const Color darkSurfaceCard = Color(0xFF1C1C1E);
  static const Color darkTextPrimary = Color(0xFFF4F4F5);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkBorderSubtle = Color(0xFF27272A);

  static ThemeData createThemeData({
    required AppThemePreset preset,
    required bool isDark,
  }) {
    final bg = preset.bgPrimary(isDark);
    final surface = preset.surfaceCard(isDark);
    final text = preset.textPrimary(isDark);
    final sec = preset.textSecondary(isDark);
    final border = preset.borderSubtle(isDark);
    final accent = preset.accentColor(isDark);
    final onAccent = preset.onAccentColor(isDark);

    final baseTextTheme = isDark
        ? GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
        outline: border,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: text,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: sec,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get lightTheme =>
      createThemeData(preset: AppThemePreset.monochrome, isDark: false);
  static ThemeData get darkTheme =>
      createThemeData(preset: AppThemePreset.monochrome, isDark: true);
}
