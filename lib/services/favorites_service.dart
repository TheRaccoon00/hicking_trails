import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trail.dart';

class FavoritesService {
  static const String _idsKey = 'favorite_trails'; 
  static const String _dataKey = 'favorite_trails_data'; 

  static Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? favList = prefs.getStringList(_idsKey);
    return favList?.toSet() ?? {};
  }

  static Future<List<Trail>> getFavoriteTrails() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> dataList = prefs.getStringList(_dataKey) ?? [];
    
    List<Trail> result = [];
    for (var jsonStr in dataList) {
      try {
        final Map<String, dynamic> element = json.decode(jsonStr);
        // Using the new streamlined restorer
        result.add(Trail.fromCacheJson(element));
      } catch (e) {
        // Skip corrupted data
      }
    }
    return result;
  }

  static Future<void> toggleFavorite(Trail trail) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> favs = (prefs.getStringList(_idsKey) ?? []).toSet();
    final List<String> dataList = prefs.getStringList(_dataKey) ?? [];
    
    if (favs.contains(trail.id)) {
      favs.remove(trail.id);
      dataList.removeWhere((item) => json.decode(item)['id'].toString() == trail.id);
    } else {
      favs.add(trail.id);
      // Simplified storage using trail.toJson()
      dataList.add(json.encode(trail.toJson()));
    }
    
    await prefs.setStringList(_idsKey, favs.toList());
    await prefs.setStringList(_dataKey, dataList);
  }
  
  static Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> favs = (prefs.getStringList(_idsKey) ?? []).toSet();
    final List<String> dataList = prefs.getStringList(_dataKey) ?? [];
    
    favs.remove(id);
    dataList.removeWhere((item) => json.decode(item)['id'].toString() == id);
    
    await prefs.setStringList(_idsKey, favs.toList());
    await prefs.setStringList(_dataKey, dataList);
  }
}
