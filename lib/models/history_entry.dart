import 'package:latlong2/latlong.dart';

class HistoryEntry {
  final String id;
  final String trailId;
  final String trailName;
  final List<LatLng> userPath;
  final int elapsedSeconds;
  final DateTime startTime;
  bool isFinished;
  final int pointsCount;

  HistoryEntry({
    required this.id,
    required this.trailId,
    required this.trailName,
    required this.userPath,
    required this.elapsedSeconds,
    required this.startTime,
    this.isFinished = false,
    this.pointsCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trailId': trailId,
      'trailName': trailName,
      'userPath': userPath.map((p) => [p.latitude, p.longitude]).toList(),
      'elapsedSeconds': elapsedSeconds,
      'startTime': startTime.toIso8601String(),
      'isFinished': isFinished,
    };
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'],
      trailId: json['trailId'],
      trailName: json['trailName'],
      userPath: (json['userPath'] as List)
          .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(),
      elapsedSeconds: json['elapsedSeconds'],
      startTime: DateTime.parse(json['startTime']),
      isFinished: json['isFinished'] ?? false,
      pointsCount: json['pointsCount'] ?? (json['userPath'] as List).length,
    );
  }
}
