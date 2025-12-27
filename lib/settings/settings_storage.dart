import 'package:shared_preferences/shared_preferences.dart';
import 'settings_model.dart';

class SettingsStorage {

  static const _distanceKey = 'alert_distance';
  static const _soundKey = 'alarm_sound';
  static const _vibrationKey = 'vibration';

  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return AppSettings(
      alertDistance: prefs.getDouble(_distanceKey) ?? 500,
      alarmSound: prefs.getString(_soundKey) ?? 'alarm1',
      vibration: prefs.getBool(_vibrationKey) ?? true,
    );
  }

  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble(_distanceKey, settings.alertDistance);
    await prefs.setString(_soundKey, settings.alarmSound);
    await prefs.setBool(_vibrationKey, settings.vibration);
  }
}
