import 'dart:convert';
import 'package:universal_html/html.dart' as html;

Future<void> saveAndShareGpx(String xml, String fileName) async {
  final bytes = utf8.encode(xml);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
    
  html.Url.revokeObjectUrl(url);
}
