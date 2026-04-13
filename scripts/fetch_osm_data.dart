import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const String overpassUrl = "https://overpass-api.de/api/interpreter";
  
  // Using ISO 3166-1 alpha-2 codes for robust country targeting
  final Map<String, String> countries = {
    "France": "FR",
    "Spain": "ES",
    "Belgium": "BE",
    "Switzerland": "CH",
    "Portugal": "PT",
    "Italy": "IT"
  };
  
  List<dynamic> combinedElements = [];

  print('===========================================================');
  print('Starting batch Overpass query for iwn and nwn trails...');
  print('Targeting: ${countries.keys.join(', ')}');
  print('===========================================================');

  for (var entry in countries.entries) {
    String name = entry.key;
    String isoCode = entry.value;
    print('Fetching data for $name ($isoCode)...');
    
    // We break them down into separate queries to guarantee they pass without timeout!
    String query = """
      [out:json][timeout:300];
      area["ISO3166-1"="$isoCode"]->.searchArea;
      (
        relation["route"~"hiking|foot"]["network"~"nwn|iwn"](area.searchArea);
      );
      out geom;
    """;

    try {
      final response = await http.post(
        Uri.parse(overpassUrl),
        body: query,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>? ?? [];
        combinedElements.addAll(elements);
        print(' -> Successfully fetched ${elements.length} routes for $name.');
      } else {
        print(' -> Failed to fetch $name. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print(' -> Error fetching $name: $e');
    }
    
    // Gentle polite delay for Overpass API between regions
    await Future.delayed(const Duration(seconds: 5));
  }

  print('\nAll countries processed. Merging and saving...');
  final Map<String, dynamic> finalJson = {
    "version": 0.6,
    "generator": "Overpass API Batch",
    "elements": combinedElements
  };

  final file = File('assets/trails_offline.json');
  if (!await file.parent.exists()) {
    await file.parent.create();
  }
  await file.writeAsString(json.encode(finalJson));

  double megabytes = file.lengthSync() / (1024 * 1024);
  print('Success! Data saved to ${file.path} (${megabytes.toStringAsFixed(2)} MB)');
}
