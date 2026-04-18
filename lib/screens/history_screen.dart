import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/history_entry.dart';
import '../services/history_service.dart';
import '../services/offline_data_service.dart';
import '../models/trail.dart';
import 'hiking_mode_screen.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry>? _history;
  bool _isProcessing = false;
  String? _resumingId; // Track which specific item is loading

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  String _formatDuration(int seconds) {
    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _resumeSession(HistoryEntry entryMetadata) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _resumingId = entryMetadata.id;
    });

    final messenger = ScaffoldMessenger.of(context);
    
    try {
      // 1. Load the full entry with the GPS path
      final fullEntry = await HistoryService.getFullEntry(entryMetadata.id);
      
      if (fullEntry == null) {
        if (mounted) setState(() {
          _isProcessing = false;
          _resumingId = null;
        });
        messenger.showSnackBar(const SnackBar(content: Text("Fichier de session introuvable")));
        return;
      }

      // 2. Load the trail
      Trail? trail;
      try {
        trail = await OfflineDataService.getTrailById(fullEntry.trailId);
      } catch (e) {
        debugPrint("Trail lookup error: $e");
      }

      // Fallback: create a dummy trail with the same ID/Name if not found
      trail ??= Trail(
        id: fullEntry.trailId,
        name: fullEntry.trailName,
        lengthKm: 0,
        coordinateSegments: [],
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HikingModeScreen(
            trail: trail!,
            existingSession: fullEntry,
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _resumingId = null;
          });
          _loadHistory();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _resumingId = null;
        });
      }
      messenger.showSnackBar(
        SnackBar(content: Text("Erreur lors de la reprise: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('history'),
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
      ),
      body: _history == null
          ? const Center(child: CircularProgressIndicator())
          : _history!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: AppTheme.grayUnselected),
                      const SizedBox(height: 16),
                      Text("Aucun historique pour le moment",
                          style: TextStyle(color: AppTheme.grayUnselected)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history!.length,
                  itemBuilder: (context, index) {
                    final entry = _history![index];
                    final isResumingThis = _resumingId == entry.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.hiking, color: AppTheme.darkGreen),
                        ),
                        title: Text(entry.trailName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "${entry.startTime.day}/${entry.startTime.month} • ${_formatDuration(entry.elapsedSeconds)} • ${entry.pointsCount} pts",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isResumingThis)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonOrange),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.play_arrow, color: AppTheme.neonOrange),
                                onPressed: _isProcessing ? null : () => _resumeSession(entry),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: _isProcessing ? null : () async {
                                setState(() => _isProcessing = true);
                                await HistoryService.deleteEntry(entry.id);
                                if (mounted) {
                                  setState(() => _isProcessing = false);
                                  _loadHistory();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
