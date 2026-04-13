import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareGpx(String xml, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(xml);
  
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Tracé GPX : $fileName',
  );
}
