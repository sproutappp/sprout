import 'package:shared_preferences/shared_preferences.dart';

class SettingsPreferences {
  SettingsPreferences._();

  static const _notificationsEnabledKey = 'settings_notifications_enabled';
  static const _dataUsageKey = 'settings_data_usage';

  static const dataUsageWifiOnly = 'wifi_only';
  static const dataUsageWifiAndMobile = 'wifi_and_mobile';

  static Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }

  static Future<String> dataUsage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dataUsageKey) ?? dataUsageWifiAndMobile;
  }

  static Future<void> setDataUsage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dataUsageKey, value);
  }
}
