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
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  LatLng? _mapCenter;
  double _mapZoom = 8.0;
  List<Trail> _trails = []; // Map gets the buffered list
  List<Trail> _listTrails = []; // List strictly gets the visible slice
  bool _isZoomTooFar = false;
  String? _selectedTrailId;

  final double _minZoomLimit = 4.0;
  final MapController _mapController = MapController();

  // Optimization Thresholds
  LatLngBounds? _lastFetchedBounds;
  LatLng? _lastFetchedCenter;

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
      // Lazy-loading: we no longer load 338MB at startup!

      final double? sLat = SettingsService.lastLat;
      final double? sLon = SettingsService.lastLon;
      final int? sTime = SettingsService.lastLocationTime;

      final prefs = await SharedPreferences.getInstance();
      double? sZoom = prefs.getDouble('last_zoom');

      bool needsFetch = true;
      if (sLat != null && sLon != null && sTime != null) {
        int now = DateTime.now().millisecondsSinceEpoch;
        if (now - sTime < 86400000) {
          // 24h in ms
          needsFetch = false;
        }
      }

      if (needsFetch) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
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
          _isZoomTooFar = (sZoom ?? 8.0) < _minZoomLimit;
          _isLoading = false;
        });
      } else {
        // absolute fallback
        if (!mounted) return;
        setState(() {
          _mapCenter = LatLng(48.8566, 2.3522); // Paris fallback
          _mapZoom = 8.0;
          _isLoading = false;
          _isZoomTooFar = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Offline Initialization Error: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  double _getBufferFactor(double zoom) {
    if (zoom >= 13.0) return 2.0;
    if (zoom >= 10.0) return 1.5;
    if (zoom >= 8.0) return 1.2;
    return 1.1;
  }

  Future<void> _fetchTrailsInBounds(
    LatLngBounds originalBounds,
    double currentZoom,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      double factor = _getBufferFactor(currentZoom);
      double latDelta = originalBounds.north - originalBounds.south;
      double lonDelta = originalBounds.east - originalBounds.west;

      double minLat = (originalBounds.south - latDelta * factor).clamp(
        -90.0,
        90.0,
      );
      double maxLat = (originalBounds.north + latDelta * factor).clamp(
        -90.0,
        90.0,
      );
      double minLon = (originalBounds.west - lonDelta * factor).clamp(
        -180.0,
        180.0,
      );
      double maxLon = (originalBounds.east + lonDelta * factor).clamp(
        -180.0,
        180.0,
      );

      LatLngBounds bufferedBounds = LatLngBounds(
        LatLng(minLat, minLon),
        LatLng(maxLat, maxLon),
      );

      List<Trail> trails;
      if (SettingsService.useCloudApi) {
        trails = await CloudApiService.getTrailsInBounds(bufferedBounds);
      } else {
        // Lazy-load if switching to offline mode
        await OfflineDataService.loadOfflineData();
        trails = await OfflineDataService.getTrailsInBounds(bufferedBounds);
      }

      if (!mounted) return;
      setState(() {
        _lastFetchedBounds = bufferedBounds;
        _trails = trails;
        _isLoading = false;
      });
      _updateStrictListTrails(originalBounds, trails);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onMapMoveEnd(LatLngBounds bounds, double zoom) async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('last_lat', bounds.center.latitude);
    prefs.setDouble('last_lon', bounds.center.longitude);
    prefs.setDouble('last_zoom', zoom);

    if (zoom < _minZoomLimit) {
      setState(() {
        _isZoomTooFar = true;
        _trails = [];
        _listTrails = [];
        _lastFetchedCenter = null;
        _lastFetchedBounds = null;
      });
      return;
    }

    setState(() {
      _isZoomTooFar = false;
    });

    bool needsUpdate = true;
    if (_lastFetchedCenter != null && _lastFetchedBounds != null) {
      double latMovement =
          (bounds.center.latitude - _lastFetchedCenter!.latitude).abs();
      double lonMovement =
          (bounds.center.longitude - _lastFetchedCenter!.longitude).abs();

      double currentLatBox = bounds.north - bounds.south;
      double currentLonBox = bounds.east - bounds.west;

      double factor = _getBufferFactor(zoom);

      // Tolerate movement up to 40% of the buffered zone without rebuilding
      if (latMovement < currentLatBox * factor * 0.40 &&
          lonMovement < currentLonBox * factor * 0.40) {
        needsUpdate = false;
      }
      
      // Safety: if we have NO trails in memory, but we finished loading, force a refresh
      if (_trails.isEmpty && !_isLoading) {
          needsUpdate = true;
      }
    }

    if (needsUpdate) {
      _lastFetchedCenter = bounds.center;
      _fetchTrailsInBounds(bounds, zoom);
    } else {
      _updateStrictListTrails(bounds, _trails);
    }
  }

  void _updateStrictListTrails(
    LatLngBounds strictBounds,
    List<Trail> activeTrails,
  ) async {
    List<Trail> strictList = [];
    for (var trail in activeTrails) {
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
    if (mounted) {
      setState(() {
        _listTrails = strictList;
      });
    }
  }

  void _onTrailSelected(String id) {
    if (!mounted) return;

    // Auto-pan map if selecting a new trail
    if (_selectedTrailId != id) {
      try {
        Trail t = _trails.firstWhere((t) => t.id == id);
        if (t.coordinateSegments.isNotEmpty &&
            t.coordinateSegments.first.isNotEmpty) {
          _mapController.move(t.coordinateSegments.first.first, 12);
        }
      } catch (e) {
        // ignore if not found
      }
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
                  _currentIndex = 0; // Switch to Map Tab
                  _selectedTrailId = selected.id;
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
            trails: _trails,
            mapController: _mapController,
            selectedTrailId: _selectedTrailId,
            onTrailTap: _onTrailSelected,
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
                  onTrailTap: _onTrailSelected,
                ),
              );
            },
          ),
        ],
      );
    } else {
      // We are in Favorites tab, ensure data is loaded for favorites list
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
                onTrailTap: _onTrailSelected,
              );
            },
          ),
        ],
      );
    }

    return Stack(
      children: [
        content,

        if (_isZoomTooFar && _currentIndex == 0)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: const Text(
                "Zoom in to see hiking trails",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else if (_isLoading)
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
