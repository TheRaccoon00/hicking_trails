import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class Trail {
  final String id;
  final String name;
  final List<List<LatLng>> coordinateSegments;
  final String? from;
  final String? to;
  double? distanceToUser;
  double lengthKm = 0.0;

  Trail({
    required this.id,
    required this.name,
    required this.coordinateSegments,
    this.from,
    this.to,
    this.distanceToUser,
    this.lengthKm = 0.0,
  });

  factory Trail.fromJson(Map<String, dynamic> json, List<List<LatLng>> segments) {
    var tags = json['tags'] ?? {};
    String? rawName = tags['name'];
    String? fromTag = tags['from'];
    String? toTag = tags['to'];
    
    String finalName = 'Unnamed Route';
    
    if (rawName != null && fromTag != null && toTag != null) {
        finalName = '$rawName ($fromTag ➔ $toTag)';
    } else if (fromTag != null && toTag != null) {
        finalName = '$fromTag ➔ $toTag';
    } else if (rawName != null) {
        finalName = rawName;
    }

    double computedLength = 0.0;
    for (var segment in segments) {
        if (segment.length > 1) {
            for (int i = 0; i < segment.length - 1; i++) {
                computedLength += haversineDist(segment[i].latitude, segment[i].longitude, segment[i+1].latitude, segment[i+1].longitude);
            }
        }
    }

    return Trail(
      id: json['id'].toString(),
      name: finalName,
      coordinateSegments: segments,
      from: fromTag,
      to: toTag,
      lengthKm: computedLength,
    );
  }

  factory Trail.fromCacheJson(Map<String, dynamic> json) {
    var coords = json['coordinates'] as List;
    List<List<LatLng>> segments = coords.map((s) => 
      (s as List).map((p) => LatLng(p[0], p[1])).toList()
    ).toList();

    return Trail(
      id: json['id'],
      name: json['name'],
      coordinateSegments: segments,
      from: json['from'],
      to: json['to'],
      lengthKm: json['length_km']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'from': from,
      'to': to,
      'length_km': lengthKm,
      'coordinates': coordinateSegments.map((s) => 
        s.map((p) => [p.latitude, p.longitude]).toList()
      ).toList(),
    };
  }

  static double haversineDist(double lat1, double lon1, double lat2, double lon2) {
      var p = 0.017453292519943295;
      var c = cos;
      var a = 0.5 - c((lat2 - lat1) * p)/2 + 
              c(lat1 * p) * c(lat2 * p) * 
              (1 - c((lon2 - lon1) * p))/2;
      return 12742 * asin(sqrt(a)); 
  }

  void calculateDistanceToUser(double userLat, double userLon) {
    if (coordinateSegments.isEmpty) return;
    
    double minDistance = double.infinity;
    for (var segment in coordinateSegments) {
      for (var point in segment) {
        double distance = Geolocator.distanceBetween(
          userLat, userLon, point.latitude, point.longitude
        );
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }
    
    this.distanceToUser = minDistance;
  }
}
