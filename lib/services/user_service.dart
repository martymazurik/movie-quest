import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const _kNameKey = 'user_name';

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kNameKey);
    if (name == null || name.trim().isEmpty) return null;
    return name;
  }

  static Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameKey, name.trim());
  }

  static Future<void> clearName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNameKey);
  }
}
