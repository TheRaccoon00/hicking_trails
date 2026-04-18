import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/trail.dart';
import '../theme/app_theme.dart';

class CustomMapView extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<Trail> trails;
  final Function(LatLngBounds, double)? onMapMoveEnd;
  final MapController mapController;

  final String? selectedTrailId;
  final Function(String)? onTrailTap;

  const CustomMapView({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    required this.trails,
    required this.mapController,
    this.selectedTrailId,
    this.onTrailTap,
    this.onMapMoveEnd,
    this.userPath,
    this.userPosition,
  });

  final List<LatLng>? userPath;
  final LatLng? userPosition;

  @override
  State<CustomMapView> createState() => _CustomMapViewState();
}

class _CustomMapViewState extends State<CustomMapView> {
  double _rotation = 0.0;
  double _currentZoom = 8.0;
  int _lastThresholdBucket = -1;

  // Pre-computed render layers — only rebuilt when data/zoom-threshold changes
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.initialZoom;
    // Don't call _rebuildLayers here as the MapController is not yet attached to a rendered FlutterMap
  }

  @override
  void didUpdateWidget(CustomMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trails.length != widget.trails.length ||
        oldWidget.selectedTrailId != widget.selectedTrailId) {
      _rebuildLayers();
    }
  }

  int _thresholdBucket(double zoom) {
    if (zoom < 5) return 0;
    if (zoom < 7) return 1;
    if (zoom < 9) return 2;
    if (zoom < 11) return 3;
    if (zoom < 13) return 4;
    return 5;
  }

  double _minImportanceForBucket(int bucket) {
    switch (bucket) {
      case 0: return 80;
      case 1: return 50;
      case 2: return 30;
      case 3: return 15;
      case 4: return 5;
      default: return 0;
    }
  }

  void _rebuildLayers() {
    LatLngBounds? bounds;
    double zoom = _currentZoom;

    try {
      final camera = widget.mapController.camera;
      bounds = camera.visibleBounds;
      zoom = camera.zoom;
    } catch (_) {
      // MapController not ready yet, use initial values if possible
      // or skip viewport filtering for this frame
    }

    int bucket = _thresholdBucket(zoom);
    double minImportance = _minImportanceForBucket(bucket);
    _lastThresholdBucket = bucket;

    // 1. Initial filter by importance and VIEWPORT
    // We keep a small buffer (0.1 deg) around the viewport
    var filteredTrails = widget.trails.where((t) {
      if (t.id == widget.selectedTrailId) return true;
      if (t.importance < minImportance) return false;

      // Viewport check (start or end point)
      if (t.coordinateSegments.isEmpty || t.coordinateSegments.first.isEmpty) return false;
      var start = t.coordinateSegments.first.first;
      var end = t.coordinateSegments.last.last;
      
      bool inViewport = bounds == null || bounds.contains(start) || bounds.contains(end);
      return inViewport;
    }).toList();

    // 2. Cap at 1500 for rendering performance
    if (filteredTrails.length > 1500) {
      filteredTrails.sort((a, b) => b.importance.compareTo(a.importance));
      var sel = filteredTrails.where((t) => t.id == widget.selectedTrailId).toList();
      var others = filteredTrails.where((t) => t.id != widget.selectedTrailId).take(1500).toList();
      filteredTrails = [...sel, ...others];
    }

    // 3. IMPORTANT: Sort by importance ASCENDING for Z-order
    // (High importance trails added last -> drawn on top)
    var unselected = filteredTrails.where((t) => t.id != widget.selectedTrailId).toList();
    unselected.sort((a, b) => a.importance.compareTo(b.importance));
    
    // Sub-sampling step for long polylines
    int step = 1;
    if (zoom < 8.0) { step = 50; }
    else if (zoom < 11.0) { step = 20; }
    else if (zoom < 13.0) { step = 8; }

    var selected = filteredTrails.where((t) => t.id == widget.selectedTrailId).toList();
    var orderedTrails = [...unselected, ...selected];

    List<Polyline> polylines = [];
    List<Marker> markers = [];

    double zoomScale = (zoom / 10.0).clamp(0.4, 3.0);

    for (var trail in orderedTrails) {
      bool isSelected = trail.id == widget.selectedTrailId;

      Color color;
      double baseWeight;
      if (isSelected) {
        color = AppTheme.neonOrange; baseWeight = 5.0;
      } else if (trail.importance >= 80) {
        color = AppTheme.emeraldGR; baseWeight = 4.0;
      } else if (trail.importance >= 55) {
        color = AppTheme.forestRegional; baseWeight = 2.5;
      } else {
        color = AppTheme.sageLocal; baseWeight = 1.2;
      }

      double markerSize = (10.0 + (trail.importance / 100.0) * 18.0) * zoomScale;
      if (isSelected) markerSize += 4.0;

      // Start marker (Puck)
      if (trail.coordinateSegments.isNotEmpty && trail.coordinateSegments.first.isNotEmpty) {
        markers.add(Marker(
          point: trail.coordinateSegments.first.first,
          width: markerSize,
          height: markerSize,
          child: GestureDetector(
            onLongPress: () => widget.onTrailTap?.call(trail.id), // Added long press for redundancy
            onTap: () => widget.onTrailTap?.call(trail.id),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.neonOrange : color.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: isSelected ? 6 : 3,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: isSelected
                  ? Icon(Icons.star, color: Colors.white, size: markerSize * 0.5)
                  : null,
            ),
          ),
        ));
      }

      // Build polylines ONLY if selected
      if (isSelected) {
        double strokeW = (baseWeight + 2.0) * zoomScale;
        List<LatLng> currentLine = [];
        for (var segment in trail.coordinateSegments) {
          List<LatLng> pts = segment;
          if (step > 1 && segment.length > 2) {
            pts = [];
            for (int j = 0; j < segment.length; j += step) {
              pts.add(segment[j]);
            }
            if (pts.last.latitude != segment.last.latitude ||
                pts.last.longitude != segment.last.longitude) {
              pts.add(segment.last);
            }
          }

          if (currentLine.isEmpty) {
            currentLine.addAll(pts);
          } else {
            double dLat = (currentLine.last.latitude - pts.first.latitude).abs();
            double dLon = (currentLine.last.longitude - pts.first.longitude).abs();
            if (dLat < 0.02 && dLon < 0.02) {
              currentLine.addAll(pts);
            } else {
              polylines.add(Polyline(
                  points: currentLine, color: color, strokeWidth: strokeW));
              currentLine = List.from(pts);
            }
          }
        }
        if (currentLine.isNotEmpty) {
          polylines.add(
              Polyline(points: currentLine, color: color, strokeWidth: strokeW));
        }
      }
    }

    _polylines = polylines;
    _markers = markers;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            onTap: (tapPosition, point) {
              // Optimized hit-test: only check start point of each trail
              double closestDist = double.infinity;
              String? closestId;
              for (var trail in widget.trails) {
                if (trail.coordinateSegments.isEmpty || trail.coordinateSegments.first.isEmpty) continue;
                var start = trail.coordinateSegments.first.first;
                double dist = Trail.haversineDist(point.latitude, point.longitude, start.latitude, start.longitude);
                if (dist < closestDist) { closestDist = dist; closestId = trail.id; }
              }
              if (closestDist < 2.0 && closestId != null) {
                widget.onTrailTap?.call(closestId);
              }
            },
            onMapReady: () {
              _rebuildLayers();
              setState(() {});
              widget.onMapMoveEnd?.call(widget.mapController.camera.visibleBounds, widget.mapController.camera.zoom);
            },
            onMapEvent: (MapEvent event) {
              _currentZoom = event.camera.zoom;
              bool needsRebuild = false;

              // Rebuild when zoom crosses an importance threshold
              int newBucket = _thresholdBucket(_currentZoom);
              if (newBucket != _lastThresholdBucket) {
                needsRebuild = true;
              }

              // Rebuild when dragging finishes (to populate holes)
              if (event is MapEventMoveEnd) {
                needsRebuild = true;
              }

              // Track rotation for compass (infrequent)
              if (event.camera.rotation != _rotation) {
                _rotation = event.camera.rotation;
                needsRebuild = true;
              }

              if (needsRebuild) {
                _rebuildLayers();
                setState(() {});
              }

              if (event is MapEventMoveEnd) {
                widget.onMapMoveEnd?.call(event.camera.visibleBounds, event.camera.zoom);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.otaviatrails.app',
            ),
            PolylineLayer(polylines: _polylines),
            if (widget.userPath != null && widget.userPath!.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.userPath!,
                    strokeWidth: 4.0,
                    color: Colors.blue[900]!,
                  ),
                ],
              ),
            MarkerLayer(markers: _markers),
            if (widget.userPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userPosition!,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_rotation != 0)
          Positioned(
            top: 16, right: 16,
            child: FloatingActionButton.small(
              heroTag: 'compass',
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              onPressed: () {
                widget.mapController.rotate(0);
                setState(() { _rotation = 0; });
              },
              child: Transform.rotate(
                angle: -_rotation * (3.14159 / 180),
                child: const Icon(Icons.explore, color: AppTheme.darkGreen, size: 24),
              ),
            ),
          ),
      ],
    );
  }
}
