import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get language => _prefs.getString('language') ?? 'fr';
  static Future<void> setLanguage(String lang) async {
    await _prefs.setString('language', lang);
  }

  static bool get useCloudApi => _prefs.getBool('use_cloud_api') ?? false;
  static Future<void> setUseCloudApi(bool val) async {
    await _prefs.setBool('use_cloud_api', val);
  }

  static double? get lastLat => _prefs.getDouble('last_lat');
  static double? get lastLon => _prefs.getDouble('last_lon');
  static int? get lastLocationTime => _prefs.getInt('last_loc_time');

  static Future<void> saveLocation(double lat, double lon) async {
    await _prefs.setDouble('last_lat', lat);
    await _prefs.setDouble('last_lon', lon);
    await _prefs.setInt('last_loc_time', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clearAllData() async {
    await _prefs.clear();
  }
}
