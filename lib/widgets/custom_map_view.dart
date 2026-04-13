import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/trail.dart';

class CustomMapView extends StatelessWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<Trail> trails;
  final Function(LatLngBounds, double)? onMapMoveEnd;
  final MapController mapController;

  final String? selectedTrailId;
  final Function(String)? onTrailTap;

  const CustomMapView({
    Key? key,
    required this.initialCenter,
    required this.initialZoom,
    required this.trails,
    required this.mapController,
    this.selectedTrailId,
    this.onTrailTap,
    this.onMapMoveEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Polyline> polylines = [];
    List<Marker> startPins = [];

    // Geometric Sub-Sampling to maintain 60FPS on massive zooms.
    int step = 1;
    if (initialZoom < 8.0) {
        step = 50; 
    } else if (initialZoom < 11.0) {
        step = 20; 
    } else if (initialZoom < 13.0) {
        step = 8; 
    }

    var unselectedTrails = trails.where((t) => t.id != selectedTrailId).toList();
    var selectedTrails = trails.where((t) => t.id == selectedTrailId).toList();
    var orderedTrails = [...unselectedTrails, ...selectedTrails]; // Ensure selected elements render ON TOP

    for (int i = 0; i < orderedTrails.length; i++) {
        var trail = orderedTrails[i];
        bool isSelected = trail.id == selectedTrailId;
        
        Color color = isSelected ? const Color(0xFFFF5F1F) : const Color(0xFF9CA3AF).withOpacity(0.9);
        
        // Add starting pin (Colored consistently neon orange)
        if (trail.coordinateSegments.isNotEmpty && trail.coordinateSegments.first.isNotEmpty) {
            startPins.add(Marker(
                point: trail.coordinateSegments.first.first,
                width: 32.0, height: 32.0,
                child: GestureDetector(
                    onTap: () {
                        if (onTrailTap != null) onTrailTap!(trail.id);
                    },
                    child: Icon(Icons.location_on, color: const Color(0xFFFF5F1F), size: isSelected ? 32.0 : 20.0),
                ),
            ));
        }

        double strokeW = initialZoom <= 8.0 ? 2.0 : 4.0;
        if (isSelected) {
            strokeW += 3.0; // Thick selection
        } else if (trail.distanceToUser != null && trail.distanceToUser! < 50000) {
            strokeW += 1.0; 
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

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onTap: (tapPosition, point) {
            double closestDist = double.infinity;
            String? closestId;
            for(var trail in trails) {
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
                if (onTrailTap != null) onTrailTap!(closestId);
            }
        },
        onMapReady: () {
            if (onMapMoveEnd != null) {
                onMapMoveEnd!(mapController.camera.visibleBounds, mapController.camera.zoom);
            }
        },
        onMapEvent: (MapEvent event) {
            if (event is MapEventMoveEnd && onMapMoveEnd != null) {
                onMapMoveEnd!(event.camera.visibleBounds, event.camera.zoom);
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
    );
  }
}
