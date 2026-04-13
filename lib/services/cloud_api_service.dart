import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/trail.dart';

class CloudApiService {
  static const String endpoint = "https://v8gd0grz85.execute-api.ap-southeast-1.amazonaws.com/trails";

  static Future<List<Trail>> getTrailsInBounds(LatLngBounds bounds) async {
    final uri = Uri.parse("$endpoint?minLat=${bounds.south}&minLon=${bounds.west}&maxLat=${bounds.north}&maxLon=${bounds.east}");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> trailsJson = data['trails'] ?? [];
      
      List<Trail> result = [];
      for (var element in trailsJson) {
         List<List<LatLng>> segments = [];
         if (element['segments'] != null) {
            for(var segment in element['segments']) {
                List<LatLng> coords = (segment as List).map((pt) {
                   return LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
                }).toList();
                segments.add(coords);
            }
         }
         
         // Try to parse using fromJson safely
         try {
             result.add(Trail.fromJson(element, segments));
         } catch (e) {
             // Fallback minimal trail parse
             try {
                String id = element['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
                String name = element['tags']?['name'] ?? "Sentier inconnu";
                result.add(Trail(id: id, name: name, coordinateSegments: segments));
             } catch (_) {}
         }
      }
      return result;
    } else {
      throw Exception("Cloud API Error: ${response.statusCode}");
    }
  }
}
