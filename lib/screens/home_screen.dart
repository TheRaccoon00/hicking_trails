import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/settings_service.dart';
import '../services/offline_data_service.dart';
import '../services/cloud_api_service.dart';
import '../services/favorites_service.dart';
import '../l10n/app_localizations.dart';
import '../models/trail.dart';
import '../widgets/custom_map_view.dart';
import '../widgets/trail_list_view.dart';
import 'trail_search_delegate.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  LatLng? _mapCenter;
  double _mapZoom = 8.0;
  final Map<String, Trail> _cachedTrails = {}; // Cumulative cache
  List<Trail> _listTrails = []; // Strictly visible trails
  String? _selectedTrailId;

  final MapController _mapController = MapController();

  // Zone-based fetching
  final Set<String> _fetchedZoneKeys = {};
  double _currentZoom = 8.0;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final double? sLat = SettingsService.lastLat;
      final double? sLon = SettingsService.lastLon;
      final int? sTime = SettingsService.lastLocationTime;

      final prefs = await SharedPreferences.getInstance();
      double? sZoom = prefs.getDouble('last_zoom');

      bool needsFetch = true;
      if (sLat != null && sLon != null && sTime != null) {
        int now = DateTime.now().millisecondsSinceEpoch;
        if (now - sTime < 86400000) {
          needsFetch = false;
        }
      }

      if (needsFetch) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          );
          await SettingsService.saveLocation(
            position.latitude,
            position.longitude,
          );
        } catch (_) {}
      }

      final double? fLat = SettingsService.lastLat;
      final double? fLon = SettingsService.lastLon;

      if (fLat != null && fLon != null) {
        LatLng storedLoc = LatLng(fLat, fLon);
        if (!mounted) return;
        setState(() {
          _mapCenter = storedLoc;
          _mapZoom = sZoom ?? 8.0;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _mapCenter = LatLng(48.8566, 2.3522); // Paris fallback
          _mapZoom = 8.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Initialization Error: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  double _getMinImportance(double zoom) {
    if (zoom < 5) return 85;
    if (zoom < 7) return 65;
    if (zoom < 9) return 45;
    if (zoom < 11) return 25;
    if (zoom < 13) return 10;
    return 0;
  }

  String _zoneKey(double south, double west, double latSize, double lonSize) {
    int latIdx = (south / latSize).floor();
    int lonIdx = (west / lonSize).floor();
    return '${latIdx}_${lonIdx}_${latSize.toStringAsFixed(3)}_${lonSize.toStringAsFixed(3)}';
  }

  Future<void> _fetchZone(
    double south,
    double west,
    double north,
    double east,
    String key, {
    bool showLoading = false,
  }) async {
    if (_fetchedZoneKeys.contains(key)) return;
    _fetchedZoneKeys.add(key);

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      var bounds = LatLngBounds(
        LatLng(south.clamp(-90.0, 90.0), west.clamp(-180.0, 180.0)),
        LatLng(north.clamp(-90.0, 90.0), east.clamp(-180.0, 180.0)),
      );

      List<Trail> trails;
      if (SettingsService.useCloudApi) {
        trails = await CloudApiService.getTrailsInBounds(bounds);
      } else {
        await OfflineDataService.loadOfflineData();
        trails = await OfflineDataService.getTrailsInBounds(bounds);
      }

      if (!mounted) return;
      setState(() {
        for (var t in trails) {
          _cachedTrails[t.id] = t;
        }
        if (showLoading) _isLoading = false;
      });
    } catch (_) {
      if (showLoading && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onMapMoveEnd(LatLngBounds bounds, double zoom) {
    if (!mounted) return;
    _currentZoom = zoom;

    // Save position fire-and-forget
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('last_lat', bounds.center.latitude);
      prefs.setDouble('last_lon', bounds.center.longitude);
      prefs.setDouble('last_zoom', zoom);
    });

    double latSize = (bounds.north - bounds.south).abs();
    double lonSize = (bounds.east - bounds.west).abs();
    if (latSize < 0.001 || lonSize < 0.001) return;

    // Snap viewport to a grid aligned with viewport size
    double gridSouth = (bounds.south / latSize).floorToDouble() * latSize;
    double gridWest = (bounds.west / lonSize).floorToDouble() * lonSize;

    // 9 zones: center + 8 surrounding, all fetched async
    const offsets = [
      [0, 0],
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ];

    for (int i = 0; i < offsets.length; i++) {
      double zSouth = gridSouth + offsets[i][0] * latSize;
      double zWest = gridWest + offsets[i][1] * lonSize;
      double zNorth = zSouth + latSize;
      double zEast = zWest + lonSize;
      String key = _zoneKey(zSouth, zWest, latSize, lonSize);

      if (i == 0) {
        // Center zone: fetch immediately
        _fetchZone(
          zSouth,
          zWest,
          zNorth,
          zEast,
          key,
          showLoading: _cachedTrails.isEmpty,
        );
      } else {
        // Stagger surrounding zones to avoid network overload
        final s = zSouth, w = zWest, n = zNorth, e = zEast, k = key;
        int delayMs = i <= 4 ? 500 : 1200;
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (mounted) _fetchZone(s, w, n, e, k);
        });
      }
    }

    _updateStrictListTrails(bounds);
  }

  void _updateStrictListTrails(LatLngBounds strictBounds) {
    double minImportance = _getMinImportance(_currentZoom);
    List<Trail> strictList = [];

    for (var trail in _cachedTrails.values) {
      if (trail.importance < minImportance) continue;
      bool within = false;
      for (var segment in trail.coordinateSegments) {
        if (within) break;
        for (var pt in segment) {
          if (strictBounds.contains(pt)) {
            strictList.add(trail);
            within = true;
            break;
          }
        }
      }
    }

    strictList.sort((a, b) => b.importance.compareTo(a.importance));

    if (mounted) {
      setState(() {
        _listTrails = strictList;
      });
    }
  }

  // Called when tapping a trail on the MAP — just highlight, no pan
  void _onMapTrailTap(String id) {
    if (!mounted) return;
    setState(() {
      _selectedTrailId = _selectedTrailId == id ? null : id;
    });
  }

  // Called when tapping a trail in the LIST — highlight AND center
  void _onListTrailTap(String id) {
    if (!mounted) return;
    if (_selectedTrailId != id) {
      try {
        Trail? t = _cachedTrails[id];
        if (t != null &&
            t.coordinateSegments.isNotEmpty &&
            t.coordinateSegments.first.isNotEmpty) {
          _mapController.move(t.coordinateSegments.first.first, 12);
        }
      } catch (_) {}
    }
    setState(() {
      _selectedTrailId = _selectedTrailId == id ? null : id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Otavia trails',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              Trail? selected = await showSearch<Trail?>(
                context: context,
                delegate: TrailSearchDelegate(),
              );
              if (selected != null) {
                setState(() {
                  _currentIndex = 0;
                  _selectedTrailId = selected.id;
                  _cachedTrails[selected.id] = selected;
                });

                if (selected.coordinateSegments.isNotEmpty &&
                    selected.coordinateSegments.first.isNotEmpty) {
                  _mapController.move(
                    selected.coordinateSegments.first.first,
                    12,
                  );
                }
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Text(AppLocalizations.t('settings')),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map),
            label: AppLocalizations.t('trails'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            label: AppLocalizations.t('saved'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_mapCenter == null && _isLoading && _errorMessage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppLocalizations.t('loading')),
          ],
        ),
      );
    }

    if (_errorMessage != null && _mapCenter == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                '$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _initApp, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_mapCenter == null) {
      return const Center(child: Text('Map location not available.'));
    }

    Widget content;
    if (_currentIndex == 0) {
      content = Stack(
        children: [
          CustomMapView(
            initialCenter: _mapCenter!,
            initialZoom: _mapZoom,
            trails: _cachedTrails.values.toList(),
            mapController: _mapController,
            selectedTrailId: _selectedTrailId,
            onTrailTap: _onMapTrailTap,
            onMapMoveEnd: _onMapMoveEnd,
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: TrailListView(
                  trails: _listTrails,
                  scrollController: scrollController,
                  selectedTrailId: _selectedTrailId,
                  onTrailTap: _onListTrailTap,
                ),
              );
            },
          ),
        ],
      );
    } else {
      content = Stack(
        children: [
          FutureBuilder<List<Trail>>(
            future: FavoritesService.getFavoriteTrails(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<Trail> favTrails = snapshot.data ?? [];
              return TrailListView(
                trails: favTrails,
                hideUnloved: true,
                selectedTrailId: _selectedTrailId,
                onTrailTap: _onListTrailTap,
              );
            },
          ),
        ],
      );
    }

    return Stack(
      children: [
        content,
        if (_isLoading)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.t('loading')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
