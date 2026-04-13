import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../models/trail.dart';
import '../models/weather_day.dart';
import '../services/favorites_service.dart';
import '../widgets/trail_card.dart';
import '../l10n/app_localizations.dart';

class TrailListView extends StatefulWidget {
  final List<Trail> trails;
  final ScrollController? scrollController;
  final bool hideUnloved; // If true, rendering in favorites tab
  final String? selectedTrailId;
  final Function(String)? onTrailTap;

  const TrailListView({
      Key? key, 
      required this.trails, 
      this.scrollController, 
      this.hideUnloved = false,
      this.selectedTrailId,
      this.onTrailTap,
  }) : super(key: key);

  @override
  State<TrailListView> createState() => _TrailListViewState();
}

class _TrailListViewState extends State<TrailListView> {
  Set<String> _favorites = {};
  Map<String, List<double>> _elevationData = {};
  Map<String, bool> _isLoadingElevation = {};
  Map<String, List<WeatherDay>> _weatherData = {};
  Map<String, bool> _isLoadingWeather = {};
  RangeValues _distanceFilter = const RangeValues(0, 150);

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favs;
      });
    }
  }

  void _toggleFavorite(String id) async {
    if (widget.hideUnloved) {
        // Direct delete in favorites tab without confirmation
        await FavoritesService.removeFavorite(id);
    } else {
        try {
            Trail trail = widget.trails.firstWhere((t) => t.id == id);
            await FavoritesService.toggleFavorite(trail);
        } catch (e) {
            // fallback if trail not found in list
            await FavoritesService.removeFavorite(id);
        }
    }
    _loadFavorites();
  }

  void _fetchElevation(Trail trail) async {
      if (_elevationData.containsKey(trail.id) || _isLoadingElevation[trail.id] == true) return;
      if (!mounted) return;
      setState(() { _isLoadingElevation[trail.id] = true; });
      try {
           List<LatLng> allPts = trail.coordinateSegments.expand((s) => s).toList();
           if (allPts.isEmpty) return;
           int step = (allPts.length / 50).ceil();
           if (step < 1) step = 1;
           
           List<LatLng> sampled = [];
           for(int i = 0; i < allPts.length; i += step) sampled.add(allPts[i]);
           if (sampled.last != allPts.last) sampled.add(allPts.last);
           
           String lats = sampled.map((p) => p.latitude.toStringAsFixed(5)).join(',');
           String lons = sampled.map((p) => p.longitude.toStringAsFixed(5)).join(',');
           
           final response = await http.get(Uri.parse('https://api.open-meteo.com/v1/elevation?latitude=$lats&longitude=$lons'));
           if (response.statusCode == 200) {
               var data = json.decode(response.body);
               List<dynamic> elevations = data['elevation'] ?? [];
               double dPlus = 0;
               double dMinus = 0;
               if (elevations.isNotEmpty) {
                   for(int i = 1; i < elevations.length; i++) {
                       double diff = ((elevations[i] ?? 0.0) as num).toDouble() - ((elevations[i-1] ?? 0.0) as num).toDouble();
                       if (diff > 0) dPlus += diff;
                       if (diff < 0) dMinus += diff.abs();
                   }
               }
               if (mounted) setState(() { _elevationData[trail.id] = [dPlus, dMinus]; });
           }
      } catch (e) {
          // ignore
      } finally {
          if (mounted) setState(() { _isLoadingElevation[trail.id] = false; });
      }
  }

  void _fetchWeather(Trail trail) async {
       if (_weatherData.containsKey(trail.id) || _isLoadingWeather[trail.id] == true) return;
       if (!mounted) return;
       setState(() { _isLoadingWeather[trail.id] = true; });
       try {
            LatLng start = trail.coordinateSegments.first.first;
            String lat = start.latitude.toStringAsFixed(4);
            String lon = start.longitude.toStringAsFixed(4);
            
            final response = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto'));
            if (response.statusCode == 200) {
                var data = json.decode(response.body);
                var daily = data['daily'];
                List<WeatherDay> days = [];
                for(int i = 0; i < 5 && i < daily['time'].length; i++) {
                     double maxT = ((daily['temperature_2m_max'][i] ?? 0) as num).toDouble();
                     double minT = ((daily['temperature_2m_min'][i] ?? 0) as num).toDouble();
                     int code = (daily['weather_code'][i] ?? 0) as int;
                     days.add(WeatherDay((maxT + minT) / 2, code, daily['time'][i]));
                }
                if (mounted) setState(() { _weatherData[trail.id] = days; });
            }
       } catch (e) {
           // ignore
       } finally {
           if (mounted) setState(() { _isLoadingWeather[trail.id] = false; });
       }
  }

  @override
  Widget build(BuildContext context) {
    List<Trail> displayedTrails = widget.trails;
    if (widget.hideUnloved) {
        displayedTrails = widget.trails.where((t) => _favorites.contains(t.id)).toList();
    }

    // Filter by distance
    displayedTrails = displayedTrails.where((t) {
        double d = t.lengthKm;
        bool inRange = d >= _distanceFilter.start;
        if (_distanceFilter.end < 150) {
            inRange = inRange && d <= _distanceFilter.end;
        }
        return inRange;
    }).toList();

    // Move selected to the top physically
    if (widget.selectedTrailId != null) {
        var preFiltered = displayedTrails;
        var selectedItem = preFiltered.where((t) => t.id == widget.selectedTrailId).toList();
        var others = preFiltered.where((t) => t.id != widget.selectedTrailId).toList();
        if (selectedItem.isNotEmpty) {
             displayedTrails = [...selectedItem, ...others];
        }
    }

    final itemCount = displayedTrails.isEmpty ? 3 : displayedTrails.length + 2;

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
           return Center(
             child: Container(
               margin: const EdgeInsets.only(top: 12, bottom: 4),
               width: 50, height: 5,
               decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
             ),
           );
        }

        if (index == 1) {
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                           "${AppLocalizations.t('distance')}: ${_distanceFilter.start.round()} km - ${_distanceFilter.end.round() >= 150 ? '150+ km' : '${_distanceFilter.end.round()} km'}",
                           style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
                        ),
                        RangeSlider(
                           activeColor: const Color(0xFFFF5F1F),
                           inactiveColor: const Color(0xFFFF5F1F).withOpacity(0.3),
                           min: 0, max: 150,
                           divisions: 150,
                           values: _distanceFilter,
                           onChanged: (vals) => setState(() => _distanceFilter = vals),
                        )
                    ]
                )
            );
        }

        if (displayedTrails.isEmpty) {
           return Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                  widget.hideUnloved ? "You haven't saved any trails yet." : "No trails visible in the current map view.\nTip: Try zooming in or moving the map.", 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)
              )
           );
        }

        final trail = displayedTrails[index - 2];
        final isSelected = trail.id == widget.selectedTrailId;

        if (isSelected && !_elevationData.containsKey(trail.id) && _isLoadingElevation[trail.id] != true) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _fetchElevation(trail));
        }
        if (isSelected && !_weatherData.containsKey(trail.id) && _isLoadingWeather[trail.id] != true) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _fetchWeather(trail));
        }

        return TrailCard(
          trail: trail,
          isSelected: isSelected,
          isFav: _favorites.contains(trail.id),
          hideUnloved: widget.hideUnloved,
          onToggleFavorite: _toggleFavorite,
          onTap: (id) => widget.onTrailTap?.call(id),
          elevationData: _elevationData[trail.id],
          isElevLoading: _isLoadingElevation[trail.id] ?? false,
          weatherData: _weatherData[trail.id],
          isWeatherLoading: _isLoadingWeather[trail.id] ?? false,
        );
      },
    );
  }
}
