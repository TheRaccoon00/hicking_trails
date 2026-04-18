import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/history_entry.dart';

class HistoryService {
  static const String _indexFileName = 'history_index.json';
  static const String _oldFileName = 'hiking_history.json';
  static const String _sessionsDirName = 'sessions';

  static Future<File> _getIndexFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_indexFileName');
  }

  static Future<File> _getSessionFile(String id) async {
    final directory = await getApplicationDocumentsDirectory();
    final sessionsDir = Directory('${directory.path}/$_sessionsDirName');
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }
    return File('${sessionsDir.path}/$id.json');
  }

  static Future<void> _migrateIfNeeded() async {
    final directory = await getApplicationDocumentsDirectory();
    final oldFile = File('${directory.path}/$_oldFileName');
    
    if (await oldFile.exists()) {
      try {
        debugPrint("Migrating old history file in background...");
        final content = await oldFile.readAsString();
        
        // Use compute for the heavy lifting
        final List<HistoryEntry> history = await compute(_parseFullHistory, content);

        // 1. Create individual session files (serial operations are OK if off-thread, but here we are in main)
        // Better: write them. File.writeAsString is async but blocks for tiny moments. 
        // With many files, we should be careful.
        for (var entry in history) {
          final sessionFile = await _getSessionFile(entry.id);
          await sessionFile.writeAsString(json.encode(entry.toJson()));
        }

        // 2. Create the index
        final indexData = history.map((e) => _toIndexData(e)).toList();
        final indexFile = await _getIndexFile();
        await indexFile.writeAsString(json.encode(indexData));

        // 3. Delete old file
        await oldFile.delete();
        debugPrint("Migration complete.");
      } catch (e) {
        debugPrint("Migration failed: $e");
      }
    }
  }

  static Map<String, dynamic> _toIndexData(HistoryEntry entry) {
    return {
      'id': entry.id,
      'trailId': entry.trailId,
      'trailName': entry.trailName,
      'elapsedSeconds': entry.elapsedSeconds,
      'startTime': entry.startTime.toIso8601String(),
      'isFinished': entry.isFinished,
      'pointsCount': entry.pointsCount > 0 ? entry.pointsCount : entry.userPath.length,
    };
  }

  static Future<List<HistoryEntry>> getHistory() async {
    await _migrateIfNeeded();
    try {
      final indexFile = await _getIndexFile();
      if (!await indexFile.exists()) return [];

      final content = await indexFile.readAsString();
      if (content.isEmpty) return [];

      // Use compute even for the index if it might be large
      final List<dynamic> indexList = await compute(json.decode, content) as List<dynamic>;
      
      return indexList.map((data) {
        return HistoryEntry(
          id: data['id'],
          trailId: data['trailId'],
          trailName: data['trailName'],
          elapsedSeconds: data['elapsedSeconds'],
          startTime: DateTime.parse(data['startTime']),
          isFinished: data['isFinished'] ?? false,
          userPath: [], // Not loaded here for performance
          pointsCount: data['pointsCount'] ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint("Error reading history index: $e");
      return [];
    }
  }

  static Future<HistoryEntry?> getFullEntry(String id) async {
    try {
      final sessionFile = await _getSessionFile(id);
      if (!await sessionFile.exists()) return null;

      final content = await sessionFile.readAsString();
      
      // Use compute for parsing individual large sessions
      return await compute(_parseSingleEntry, content);
    } catch (e) {
      debugPrint("Error reading session $id: $e");
      return null;
    }
  }

  static Future<void> saveEntry(HistoryEntry entry) async {
    try {
      // 1. Save individual session file
      final sessionFile = await _getSessionFile(entry.id);
      final sessionJson = await compute(_encodeSingleEntry, entry);
      await sessionFile.writeAsString(sessionJson);

      // 2. Update the lightweight index
      final indexFile = await _getIndexFile();
      List<dynamic> indexList = [];
      if (await indexFile.exists()) {
        final content = await indexFile.readAsString();
        if (content.isNotEmpty) {
          indexList = await compute(json.decode, content) as List<dynamic>;
        }
      }

      final indexData = _toIndexData(entry);
      final index = indexList.indexWhere((e) => e['id'] == entry.id);
      if (index != -1) {
        indexList[index] = indexData;
      } else {
        indexList.insert(0, indexData);
      }

      final indexJson = await compute(json.encode, indexList);
      await indexFile.writeAsString(indexJson);
    } catch (e) {
      debugPrint("Error saving entry: $e");
    }
  }

  static Future<void> deleteEntry(String id) async {
    try {
      final sessionFile = await _getSessionFile(id);
      if (await sessionFile.exists()) await sessionFile.delete();

      final indexFile = await _getIndexFile();
      if (await indexFile.exists()) {
        final content = await indexFile.readAsString();
        final List<dynamic> indexList = await compute(json.decode, content) as List<dynamic>;
        indexList.removeWhere((e) => e['id'] == id);
        final indexJson = await compute(json.encode, indexList);
        await indexFile.writeAsString(indexJson);
      }
    } catch (e) {
      debugPrint("Error deleting entry: $e");
    }
  }
}

// Top-level functions for compute
List<HistoryEntry> _parseFullHistory(String jsonStr) {
  final List<dynamic> list = json.decode(jsonStr);
  return list.map((e) => HistoryEntry.fromJson(e)).toList();
}

HistoryEntry _parseSingleEntry(String jsonStr) {
  return HistoryEntry.fromJson(json.decode(jsonStr));
}

String _encodeSingleEntry(HistoryEntry entry) {
  return json.encode(entry.toJson());
}
