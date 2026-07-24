import 'package:flutter/material.dart';
import '../services/storage.dart';
import 'app_colors.dart';

// App theme state (light / dark / system), persisted on device.
// mode is one of 'system' | 'light' | 'dark'.
class ThemeProvider extends ChangeNotifier {
  // The Neobank design is light-first: default to light until the user picks
  // another mode in Account → Theme Settings.
  String _mode = 'light';
  Brightness _systemBrightness = Brightness.light;

  String get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final stored = await Storage.getThemeMode();
    if (stored == 'dark' || stored == 'light' || stored == 'system') {
      _mode = stored!;
      notifyListeners();
    }
  }

  void setMode(String next) {
    _mode = next;
    Storage.setThemeMode(next);
    notifyListeners();
  }

  // Kept in sync with the platform brightness by the widget tree.
  void updateSystemBrightness(Brightness brightness) {
    if (brightness != _systemBrightness) {
      _systemBrightness = brightness;
      if (_mode == 'system') notifyListeners();
    }
  }

  bool get isDark => _mode == 'system'
      ? _systemBrightness == Brightness.dark
      : _mode == 'dark';

  AppColors get colors => isDark ? AppColors.dark : AppColors.light;
}
