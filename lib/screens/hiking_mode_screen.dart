import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/trail.dart';
import '../widgets/custom_map_view.dart';
import '../l10n/app_localizations.dart';

class HikingModeScreen extends StatefulWidget {
  final Trail trail;

  const HikingModeScreen({super.key, required this.trail});

  @override
  State<HikingModeScreen> createState() => _HikingModeScreenState();
}

class _HikingModeScreenState extends State<HikingModeScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('about'), style: const TextStyle(fontWeight: FontWeight.bold)), // Reusing translation keys if specific ones missing
        content: const Text("Voulez-vous vraiment arrêter la randonnée ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Arrêter"),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Initial center is the start of the trail
    LatLng initialCenter = widget.trail.coordinateSegments.isNotEmpty && widget.trail.coordinateSegments.first.isNotEmpty 
        ? widget.trail.coordinateSegments.first.first 
        : const LatLng(48.8566, 2.3522);

    return Scaffold(
      body: Stack(
        children: [
          CustomMapView(
            initialCenter: initialCenter,
            initialZoom: 14.0,
            trails: [widget.trail],
            mapController: _mapController,
            selectedTrailId: widget.trail.id,
          ),
          
          // Header Overlay with Trail Name
          Positioned(
            top: 40, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.hiking, color: Color(0xFFFF5F1F)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.trail.name,
                      style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Control Panel
          Positioned(
            bottom: 30, left: 16, right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2F25),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("TEMPS ÉCOULÉ", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
                          Text(
                            _formatDuration(_stopwatch.elapsed),
                            style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () async {
                          if (await _showExitConfirmation()) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const CircleAvatar(
                          backgroundColor: Colors.red,
                          radius: 24,
                          child: Icon(Icons.stop, color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
