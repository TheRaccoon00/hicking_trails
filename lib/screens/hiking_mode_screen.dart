import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/trail.dart';
import '../models/history_entry.dart';
import '../services/history_service.dart';
import '../widgets/custom_map_view.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class HikingModeScreen extends StatefulWidget {
  final Trail trail;
  final HistoryEntry? existingSession;

  const HikingModeScreen({
    super.key,
    required this.trail,
    this.existingSession,
  });

  @override
  State<HikingModeScreen> createState() => _HikingModeScreenState();
}

class _HikingModeScreenState extends State<HikingModeScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  final MapController _mapController = MapController();
  
  StreamSubscription<Position>? _positionStream;
  List<LatLng> _userPath = [];
  LatLng? _currentPosition;
  double? _currentAltitude;
  Position? _rawPosition;
  bool _autoFollow = true;
  late String _sessionId;

  @override
  void initState() {
    super.initState();
    
    // Resume or Start new session
    if (widget.existingSession != null) {
      _sessionId = widget.existingSession!.id;
      _userPath = List.from(widget.existingSession!.userPath);
      _stopwatch.start(); 
    } else {
      _sessionId = const Uuid().v4();
      _stopwatch.start();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
      // Auto-save every 30 seconds
      if (timer.tick % 30 == 0) {
        _saveProgress();
      }
    });

    _initLocationTracking();
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (!mounted) return;
        final point = LatLng(position.latitude, position.longitude);
        setState(() {
          _rawPosition = position;
          _currentPosition = point;
          _currentAltitude = position.altitude;
          _userPath.add(point);
          if (_autoFollow) {
            _mapController.move(point, _mapController.camera.zoom);
          }
        });
      },
    );
  }

  Future<void> _saveProgress({bool isFinished = false}) async {
    final elapsedTotal = (widget.existingSession?.elapsedSeconds ?? 0) + _stopwatch.elapsed.inSeconds;
    
    final entry = HistoryEntry(
      id: _sessionId,
      trailId: widget.trail.id,
      trailName: widget.trail.name,
      userPath: _userPath,
      elapsedSeconds: elapsedTotal,
      startTime: widget.existingSession?.startTime ?? DateTime.now(),
      isFinished: isFinished,
    );
    await HistoryService.saveEntry(entry);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('stopHikeTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppLocalizations.t('stopHikeConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _saveProgress(isFinished: true);
              if (mounted) navigator.pop(true);
            },
            child: Text(AppLocalizations.t('stopAndSave')),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    int totalSeconds = (widget.existingSession?.elapsedSeconds ?? 0) + _stopwatch.elapsed.inSeconds;

    LatLng initialCenter = _currentPosition ?? 
        (_userPath.isNotEmpty ? _userPath.last : 
        (widget.trail.coordinateSegments.isNotEmpty && widget.trail.coordinateSegments.first.isNotEmpty 
            ? widget.trail.coordinateSegments.first.first 
            : const LatLng(48.8566, 2.3522)));

    return Scaffold(
      body: Stack(
        children: [
          // The single base map with the trail and user tracking layers
          CustomMapView(
            initialCenter: initialCenter,
            initialZoom: 15.0,
            trails: [widget.trail],
            mapController: _mapController,
            selectedTrailId: widget.trail.id,
            userPath: _userPath,
            userPosition: _currentPosition,
            onMapMoveEnd: (bounds, zoom) {
               // When user drags map, disable auto-follow
               if (_autoFollow) {
                 setState(() => _autoFollow = false);
               }
            },
          ),

          // Header Overlay
          Positioned(
            top: 40, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.hiking, color: AppTheme.neonOrange),
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

          // Auto-follow Button
          if (!_autoFollow && _currentPosition != null)
            Positioned(
              bottom: 120, right: 16,
              child: FloatingActionButton.small(
                backgroundColor: AppTheme.neonOrange,
                onPressed: () {
                  setState(() => _autoFollow = true);
                  _mapController.move(_currentPosition!, _mapController.camera.zoom);
                },
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),

          // Bottom Control Panel
          Positioned(
            bottom: 40, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2F25),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timer Column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.t('timeLabel'), style: const TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1.2)),
                      Text(
                        _formatDuration(totalSeconds),
                        style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  
                  // Altitude Column
                  if (_currentAltitude != null)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.t('altitudeLabel'), style: const TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1.2)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _currentAltitude!.toStringAsFixed(0),
                              style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 2),
                            const Text("m", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),

                  // Stop Button
                  IconButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      if (await _showExitConfirmation()) {
                        if (!mounted) return;
                        navigator.pop();
                      }
                    },
                    icon: const CircleAvatar(
                      backgroundColor: Colors.red,
                      radius: 20,
                      child: Icon(Icons.stop, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Coordinates Overlay at absolute bottom
          if (_rawPosition != null)
            Positioned(
              bottom: 8, left: 0, right: 0,
              child: Center(
                child: Text(
                  "${_rawPosition!.latitude.toStringAsFixed(5)}, ${_rawPosition!.longitude.toStringAsFixed(5)}",
                  style: GoogleFonts.robotoMono(
                    color: Colors.white70, 
                    fontSize: 10,
                    shadows: [const Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
