import 'package:xml/xml.dart';
import '../models/trail.dart';
import 'package:flutter/foundation.dart';

// Conditional imports based on platform
import '../utils/gpx_export_io.dart' if (dart.library.html) '../utils/gpx_export_web.dart' as exporter;

class GpxService {
  static Future<void> downloadGpx(Trail trail) async {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', attributes: {
      'version': '1.1',
      'creator': 'Otavia Trails',
      'xmlns': 'http://www.topografix.com/GPX/1/1',
    }, nest: () {
      builder.element('metadata', nest: () {
        builder.element('name', nest: trail.name);
      });
      builder.element('trk', nest: () {
        builder.element('name', nest: trail.name);
        builder.element('trkseg', nest: () {
          for (var segment in trail.coordinateSegments) {
            for (var pt in segment) {
              builder.element('trkpt', attributes: {
                'lat': pt.latitude.toString(),
                'lon': pt.longitude.toString(),
              });
            }
          }
        });
      });
    });

    final gpxString = builder.buildDocument().toXmlString(pretty: true);
    final fileName = "${trail.name.replaceAll(RegExp(r'[^\w\s\-]'), '')}.gpx";

    await exporter.saveAndShareGpx(gpxString, fileName);
  }
}
