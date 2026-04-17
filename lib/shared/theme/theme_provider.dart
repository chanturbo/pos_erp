// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────
// Font Settings State
// ─────────────────────────────────────────
class FontSettings {
  final String fontFamily; // 'ibmPlexSansThai' | 'sarabun' | 'kanit' | 'prompt' | 'notoSansThai'
  final double fontScale;  // 0.85 | 1.0 | 1.15 | 1.3

  const FontSettings({
    this.fontFamily = 'ibmPlexSansThai',
    this.fontScale = 1.0,
  });
}

class FontSettingsNotifier extends Notifier<FontSettings> {
  static const _keyFamily = 'font_family';
  static const _keyScale = 'font_scale';

  @override
  FontSettings build() {
    Future.microtask(_load);
    return const FontSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = FontSettings(
        fontFamily: prefs.getString(_keyFamily) ?? 'ibmPlexSansThai',
        fontScale: prefs.getDouble(_keyScale) ?? 1.0,
      );
    } catch (e) {
      print('⚠️ FontSettings: load error: $e');
    }
  }

  Future<void> setFontFamily(String family) async {
    state = FontSettings(fontFamily: family, fontScale: state.fontScale);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFamily, family);
    } catch (e) {
      print('⚠️ FontSettings: save error: $e');
    }
  }

  Future<void> setFontScale(double scale) async {
    state = FontSettings(fontFamily: state.fontFamily, fontScale: scale);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyScale, scale);
    } catch (e) {
      print('⚠️ FontSettings: save error: $e');
    }
  }
}

final fontSettingsProvider =
    NotifierProvider<FontSettingsNotifier, FontSettings>(
  FontSettingsNotifier.new,
);

// ─────────────────────────────────────────
// Theme Mode State
// ─────────────────────────────────────────
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system; // default ก่อน load
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      state = switch (saved) {
        'light'  => ThemeMode.light,
        'dark'   => ThemeMode.dark,
        _        => ThemeMode.system,
      };
    } catch (e) {
      print('⚠️ ThemeProvider: load error: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = switch (mode) {
        ThemeMode.light  => 'light',
        ThemeMode.dark   => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_key, val);
    } catch (e) {
      print('⚠️ ThemeProvider: save error: $e');
    }
  }

  Future<void> toggleDarkMode(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  bool get isDark => state == ThemeMode.dark;
  bool get isLight => state == ThemeMode.light;
  bool get isSystem => state == ThemeMode.system;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);