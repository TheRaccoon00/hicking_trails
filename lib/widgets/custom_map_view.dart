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
  });

  @override
  State<CustomMapView> createState() => _CustomMapViewState();
}

class _CustomMapViewState extends State<CustomMapView> {
  double _rotation = 0.0;

  @override
  Widget build(BuildContext context) {
    List<Polyline> polylines = [];
    List<Marker> startPins = [];

    // Geometric Sub-Sampling to maintain 60FPS on massive zooms.
    int step = 1;
    if (widget.initialZoom < 8.0) {
        step = 50; 
    } else if (widget.initialZoom < 11.0) {
        step = 20; 
    } else if (widget.initialZoom < 13.0) {
        step = 8; 
    }

    var unselectedTrails = widget.trails.where((t) => t.id != widget.selectedTrailId).toList();
    var selectedTrails = widget.trails.where((t) => t.id == widget.selectedTrailId).toList();
    var orderedTrails = [...unselectedTrails, ...selectedTrails]; // Ensure selected elements render ON TOP

    for (int i = 0; i < orderedTrails.length; i++) {
        var trail = orderedTrails[i];
        bool isSelected = trail.id == widget.selectedTrailId;
        
        Color color = isSelected ? AppTheme.neonOrange : AppTheme.grayUnselected.withOpacity(0.9);
        
        // Add starting pin (Colored consistently neon orange)
        if (trail.coordinateSegments.isNotEmpty && trail.coordinateSegments.first.isNotEmpty) {
            startPins.add(Marker(
                point: trail.coordinateSegments.first.first,
                width: 32.0, height: 32.0,
                child: GestureDetector(
                    onTap: () {
                        if (widget.onTrailTap != null) widget.onTrailTap!(trail.id);
                    },
                    child: Icon(Icons.location_on, color: AppTheme.neonOrange, size: isSelected ? 32.0 : 20.0),
                ),
            ));
        }

        // 2x Thicker default lines per user request
        double strokeW = widget.initialZoom <= 8.0 ? 4.0 : 8.0; 
        if (isSelected) {
            strokeW += 4.0; // Even thicker selection to stay on top
        } else if (trail.distanceToUser != null && trail.distanceToUser! < 50000) {
            strokeW += 2.0; 
        }

        List<LatLng> currentLine = [];

        for (var segment in trail.coordinateSegments) {
            List<LatLng> optimizedPoints = segment;
            
            // Apply sampling only if needed and segment is large enough
            if (step > 1 && segment.length > 2) {
                optimizedPoints = [];
                for (int j = 0; j < segment.length; j += step) {
                    optimizedPoints.add(segment[j]);
                }
                if (optimizedPoints.last.latitude != segment.last.latitude || optimizedPoints.last.longitude != segment.last.longitude) {
                    optimizedPoints.add(segment.last);
                }
            }

            if (currentLine.isEmpty) {
                currentLine.addAll(optimizedPoints);
            } else {
                // Topological Protection: OSM segments are generally ordered.
                // We only merge if the end of the current line is physically close to the start of the next segment.
                // 0.02 degrees is ~2.2 kilometers. If the gap is larger, it's a disconnected jump.
                double dLat = (currentLine.last.latitude - optimizedPoints.first.latitude).abs();
                double dLon = (currentLine.last.longitude - optimizedPoints.first.longitude).abs();
                
                if (dLat < 0.02 && dLon < 0.02) {
                    currentLine.addAll(optimizedPoints); // Glue them, saving massive overhead!
                } else {
                    // Gap detected! Commit current line to prevent drawing a straight spiderweb across cities.
                    polylines.add(
                        Polyline(points: currentLine, color: color, strokeWidth: strokeW)
                    );
                    currentLine = List.from(optimizedPoints); // Start a fresh line
                }
            }
        }
        
        // Push the final remaining line
        if (currentLine.isNotEmpty) {
            polylines.add(
                Polyline(points: currentLine, color: color, strokeWidth: strokeW)
            );
        }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            onTap: (tapPosition, point) {
                double closestDist = double.infinity;
                String? closestId;
                for(var trail in widget.trails) {
                    for(var segment in trail.coordinateSegments) {
                        for(var pt in segment) {
                            double dist = Trail.haversineDist(point.latitude, point.longitude, pt.latitude, pt.longitude);
                            if (dist < closestDist) {
                                closestDist = dist;
                                closestId = trail.id;
                            }
                        }
                    }
                }
                // Max selection distance roughly 500 meters or adjusted visually
                if (closestDist < 1.5 && closestId != null) { 
                    if (widget.onTrailTap != null) widget.onTrailTap!(closestId);
                }
            },
            onMapReady: () {
                if (widget.onMapMoveEnd != null) {
                    widget.onMapMoveEnd!(widget.mapController.camera.visibleBounds, widget.mapController.camera.zoom);
                }
            },
            onMapEvent: (MapEvent event) {
                setState(() {
                  _rotation = event.camera.rotation;
                });
                if (event is MapEventMoveEnd && widget.onMapMoveEnd != null) {
                    widget.onMapMoveEnd!(event.camera.visibleBounds, event.camera.zoom);
                }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.hiking_trails',
            ),
            PolylineLayer(
              polylines: polylines,
            ),
            MarkerLayer(
              markers: startPins,
            ),
          ],
        ),
        if (_rotation != 0)
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'compass',
              backgroundColor: Colors.white.withOpacity(0.8),
              onPressed: () {
                widget.mapController.rotate(0);
                setState(() {
                  _rotation = 0;
                });
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
