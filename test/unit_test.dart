import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:hiking_trails/models/trail.dart';

void main() {
  group('Trail Model Tests', () {
    test('Trail fromCacheJson & toJson should be consistent', () {
      final originTrail = Trail(
        id: '123',
        name: 'Sentier de Test',
        lengthKm: 5.5,
        from: 'Depart',
        to: 'Arrivée',
        coordinateSegments: [[const LatLng(48.0, 2.0), const LatLng(48.1, 2.1)]]
      );

      final json = originTrail.toJson();
      final restoredTrail = Trail.fromCacheJson(json);

      expect(restoredTrail.id, originTrail.id);
      expect(restoredTrail.name, originTrail.name);
      expect(restoredTrail.lengthKm, originTrail.lengthKm);
      expect(restoredTrail.coordinateSegments.length, originTrail.coordinateSegments.length);
      expect(restoredTrail.coordinateSegments[0][0].latitude, 48.0);
    });

    test('haversineDist calculation check', () {
      // Distance between Paris (48.8566, 2.3522) and Lyon (45.7640, 4.8357) is ~391 km
      double dist = Trail.haversineDist(48.8566, 2.3522, 45.7640, 4.8357);
      expect(dist, closeTo(391.0, 2.0));
    });
  });
}
