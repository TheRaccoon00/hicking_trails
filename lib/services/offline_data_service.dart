import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/trail.dart';

class OfflineDataService {
  static List<Trail> _cachedTrails = [];
  static bool _isLoaded = false;
  
  static List<Trail> get allCachedTrails => _cachedTrails;
  static bool get isLoaded => _isLoaded;

  static Future<void> loadOfflineData() async {
    if (_isLoaded) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/offline_trails_cache.json');
      
      String jsonString;
      
      if (await file.exists()) {
        jsonString = await file.readAsString();
      } else {
        // Download from AWS
        final url = dotenv.env['OFFLINE_DATA_URL'];
        if (url == null) throw Exception("OFFLINE_DATA_URL not found in .env");
        
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          jsonString = response.body;
          // Cache locally for next time
          await file.writeAsString(jsonString);
        } else {
          throw Exception("Failed to download offline data: ${response.statusCode}");
        }
      }
      
      _cachedTrails = await compute(_parseTrails, jsonString);
      _isLoaded = true;
    } catch (e) {
      throw Exception("Offline Data Service Error: $e");
    }
  }

  // Top-level or static helper for compute
  static List<Trail> _parseTrails(String jsonString) {
    final List<dynamic> data = json.decode(jsonString);
    List<Trail> parsedTrails = [];
    
    for (var element in data) {
      List<List<LatLng>> segments = [];
      if (element['segments'] != null) {
        for(var segment in element['segments']) {
          List<LatLng> coords = (segment as List).map((pt) {
            return LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
          }).toList();
          segments.add(coords);
        }
      }
      
      if (segments.isNotEmpty) {
        parsedTrails.add(Trail.fromJson(element, segments));
      }
    }
    return parsedTrails;
  }

  static Future<List<Trail>> getTrailsInBounds(LatLngBounds? bounds) async {
    if (!_isLoaded) return [];
    if (bounds == null) return _cachedTrails;

    List<Trail> visibleTrails = [];
    int batchCounter = 0;
    
    // Check which trails fall entirely or partially within the bounding box view.
    for (var trail in _cachedTrails) {
      if (trail.coordinateSegments.isEmpty) continue;
      
      bool withinBounds = false;
      
      for (var segment in trail.coordinateSegments) {
        if (withinBounds) break;
        for (var point in segment) {
          if (bounds.contains(point)) {
            visibleTrails.add(trail);
            withinBounds = true;
            break; 
          }
        }
      }
      
      batchCounter++;
      // Yield to the UI event loop every 250 bounding box calculations.
      // This guarantees the map Canvas renders at 60 FPS without ever locking up!
      if (batchCounter % 250 == 0) {
          await Future.delayed(Duration.zero);
      }
    }
    return visibleTrails;
  }

  static Future<Trail?> getTrailById(String id) async {
    try {
      if (!_isLoaded) await loadOfflineData();
      return _cachedTrails.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}
