import 'dart:io';
import 'dart:convert';

void main() async {
  print('Loading JSON...');
  final file = File('assets/trails_offline.json');
  final content = await file.readAsString();
  print('Decoding JSON...');
  final Map<String, dynamic> data = json.decode(content);
  final elements = data['elements'] as List;
  
  print('Total relations found: \${elements.length}');
  
  int missingGeom = 0;
  int missingMembers = 0;
  
  Map<String, int> networkCounts = {};

  double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;

  for (var rel in elements) {
    var tags = rel['tags'] ?? {};
    String network = tags['network'] ?? 'unknown';
    networkCounts[network] = (networkCounts[network] ?? 0) + 1;
    
    var members = rel['members'] as List?;
    if (members == null || members.isEmpty) {
      missingMembers++;
      continue;
    }
    
    bool hasGeom = false;
    for (var m in members) {
      var geom = m['geometry'] as List?;
      if (geom != null && geom.isNotEmpty) {
        hasGeom = true;
        for (var pt in geom) {
          double lat = (pt['lat'] as num).toDouble();
          double lon = (pt['lon'] as num).toDouble();
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lon < minLon) minLon = lon;
          if (lon > maxLon) maxLon = lon;
        }
      }
    }
    if (!hasGeom) missingGeom++;
  }
  
  print('Relations without members: \$missingMembers');
  print('Relations with empty geometry: \$missingGeom');
  print('Networks: \$networkCounts');
  print('Overall Bounding Box of Data: [\$minLat, \$minLon] to [\$maxLat, \$maxLon]');
  
}
