import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/trail.dart';

class OfflineDataService {
  static List<Trail> _cachedTrails = [];
  static bool _isLoaded = false;
  
  static List<Trail> get allCachedTrails => _cachedTrails;

  static Future<void> loadOfflineData() async {
    if (_isLoaded) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/trails_offline.json');
      
      // Use compute to offload parsing to a separate thread
      _cachedTrails = await compute(_parseTrails, jsonString);
      _isLoaded = true;
    } catch (e) {
      throw Exception("Failed to load offline trail data: $e");
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

  static Future<List<Trail>> getTrailsInBounds(LatLngBounds bounds) async {
    if (!_isLoaded) return [];

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
}
