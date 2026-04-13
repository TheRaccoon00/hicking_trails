import 'dart:io';
import 'dart:convert';
import 'package:xml/xml.dart';

void main() async {
  final List<String> countries = ["switzerland", "belgium", "portugal", "italy", "spain", "france"];
  
  List<dynamic> combinedElements = [];

  for (String c in countries) {
    File file = File('osm_data/$c-filtered.osm');
    if (!file.existsSync()) {
      print('Warning: XML dump for $c not found. Skipping...');
      continue;
    }

    print('Parsing XML for $c...');
    String content = await file.readAsString();
    final document = XmlDocument.parse(content);
    
    // Nodes mapping
    Map<String, Map<String, double>> nodes = {};
    for (var node in document.findAllElements('node')) {
      nodes[node.getAttribute('id')!] = {
        'lat': double.parse(node.getAttribute('lat')!),
        'lon': double.parse(node.getAttribute('lon')!)
      };
    }

    // Ways mapping
    Map<String, List<Map<String, double>>> ways = {};
    for (var way in document.findAllElements('way')) {
      List<Map<String, double>> coords = [];
      for (var nd in way.findAllElements('nd')) {
        var ref = nd.getAttribute('ref')!;
        if (nodes.containsKey(ref)) {
          coords.add(nodes[ref]!);
        }
      }
      ways[way.getAttribute('id')!] = coords;
    }

    // Relations processing
    for (var rel in document.findAllElements('relation')) {
      Map<String, dynamic> tags = {};
      for (var tag in rel.findAllElements('tag')) {
        tags[tag.getAttribute('k')!] = tag.getAttribute('v');
      }
      
      List<Map<String, dynamic>> members = [];
      for (var member in rel.findAllElements('member')) {
        if (member.getAttribute('type') == 'way') {
          var ref = member.getAttribute('ref')!;
          if (ways.containsKey(ref)) {
            members.add({
              'type': 'way',
              'ref': int.parse(ref),
              'role': member.getAttribute('role') ?? '',
              'geometry': ways[ref]
            });
          }
        }
      }

      if (members.isNotEmpty) {
        combinedElements.add({
          'type': 'relation',
          'id': int.parse(rel.getAttribute('id')!),
          'tags': tags,
          'members': members
        });
      }
    }
  }

  // Create identical JSON structure as Overpass
  final Map<String, dynamic> finalJson = {
    "version": 0.6,
    "generator": "Osmosis Local Parser",
    "elements": combinedElements
  };

  File outFile = File('assets/trails_offline.json');
  if (!await outFile.parent.exists()) await outFile.parent.create();
  
  print('Writing final JSON to ${outFile.path}...');
  await outFile.writeAsString(json.encode(finalJson));

  double megabytes = outFile.lengthSync() / (1024 * 1024);
  print('Successfully parsed and exported (${megabytes.toStringAsFixed(2)} MB)');
}
