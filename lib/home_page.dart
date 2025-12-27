import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:flutter_compass/flutter_compass.dart';


import 'location_service.dart';
import 'notification_service.dart';
import 'search_service.dart';
import 'route_service.dart';
import 'settings/settings_page.dart';
import 'settings/settings_storage.dart';
import 'alarm/alarm_page.dart';
import 'alarm/alarm_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? currentLocation;
  LatLng? destination;
  Timer? locationTimer;
  bool alerted = false;

  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];

  List<LatLng> routePoints = [];
  bool isRouteLoading = false;
  bool isSearching = false;


  double alertDistance = 500;

  List<RouteResult> routes = [];
  int selectedRoute = 0;

  late final MapController mapController;

  double currentHeading = 0;
  bool followDirection = true;

  Timer? _searchDebounce;


  // ================= ROUTE =================
  Future<void> fetchRoute() async {
    if (currentLocation == null || destination == null) return;

    setState(() {
      isRouteLoading = true;
      routes.clear();
    });

    try {
      routes = await RouteService.getRoutes(
        currentLocation!,
        destination!,
      );
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => isRouteLoading = false);
  }


  // ================= SEARCH =================
  void searchLocation(String query) {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.length < 3 || currentLocation == null) {
        setState(() => searchResults.clear());
        return;
      }

      setState(() => isSearching = true);

      try {
        final results = await SearchService.searchPlace(
          query,
          currentLocation!,
        );
        setState(() => searchResults = results);
      } catch (_) {}

      setState(() => isSearching = false);
    });
  }



  // ================= INIT =================
  @override
  @override
  void initState() {
    super.initState();

    mapController = MapController();

    FlutterCompass.events?.listen((event) {
      if (event.heading == null) return;

      setState(() {
        currentHeading = event.heading!;
      });

      if (followDirection) {
        mapController.rotate(-currentHeading);
      }
    });

    NotificationService.init();
    loadSettings();
    getLocation();
  }


  void loadSettings() async {
    final s = await SettingsStorage.loadSettings();
    setState(() => alertDistance = s.alertDistance);
  }

  void getLocation() async {
    Position pos = await LocationService.getCurrentLocation();
    setState(() {
      currentLocation = LatLng(pos.latitude, pos.longitude);
    });
    startTracking();
  }

  void startTracking() {
    locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      Position pos = await LocationService.getCurrentLocation();
      setState(() {
        currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      checkDistance();
    });
  }

  void checkDistance() async {
    if (destination == null || currentLocation == null || alerted) return;

    final settings = await SettingsStorage.loadSettings();

    double distance = Geolocator.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      destination!.latitude,
      destination!.longitude,
    );

    if (distance <= settings.alertDistance) {
      alerted = true;

      await AlarmService.play(settings.alarmSound);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AlarmPage()),
        );
      }
    }
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Destination Alert'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search destination',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    setState(() => searchResults.clear());
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: searchLocation,
            ),
          ),
          if (isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // 🔽 SEARCH RESULTS (ANIMATED)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: searchResults.isNotEmpty
                ? SizedBox(
              key: const ValueKey('results'),
              height: 200,
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final place = searchResults[index];
                  return ListTile(
                    title: Text(place['name']),
                    onTap: () async {
                      setState(() {
                        destination =
                            LatLng(place['lat'], place['lon']);
                        searchResults.clear();
                        searchController.text = place['name'];
                        alerted = false;
                      });
                      await fetchRoute();
                    },
                  );
                },
              ),
            )
                : const SizedBox(key: ValueKey('empty')),
          ),

          // ⏳ ROUTE LOADING BAR  ✅ (THIS IS STEP 2)
          if (isRouteLoading)
            const LinearProgressIndicator(minHeight: 3),

          if (routes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: routes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final r = entry.value;

                  return ListTile(
                    title: Text(
                      'Route ${index + 1} • ${r.distanceKm.toStringAsFixed(1)} km',
                    ),
                    subtitle: Text(
                      'ETA: ${r.durationMin.toStringAsFixed(0)} mins',
                    ),
                    trailing: selectedRoute == index
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => selectedRoute = index);
                    },
                  );
                }).toList(),
              ),
            ),

          // 🗺️ MAP
          Expanded(
            child: Stack(
              children: [
                // 🗺️ MAP
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: currentLocation!,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),

                    // 🛣️ ROUTES
                    if (routes.isNotEmpty)
                      PolylineLayer(
                        polylines: routes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final route = entry.value;
                          return Polyline(
                            points: route.points,
                            strokeWidth: index == selectedRoute ? 5 : 3,
                            color: index == selectedRoute
                                ? Colors.blue
                                : Colors.grey,
                          );
                        }).toList(),
                      ),

                    // 📍 MARKERS
                    MarkerLayer(
                      markers: [
                        // 📍 USER (ROTATES WITH PHONE)
                        Marker(
                          point: currentLocation!,
                          width: 40,
                          height: 40,
                          child: Transform.rotate(
                            angle: currentHeading * pi / 180,
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.blue,
                              size: 36,
                            ),
                          ),
                        ),

                        // 🎯 DESTINATION
                        if (destination != null)
                          Marker(
                            point: destination!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // 🧭 COMPASS (TOP-RIGHT)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Transform.rotate(
                    angle: -currentHeading * pi / 180,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 4,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.explore,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                  ),
                ),

                // 🎯 AUTO-CENTER BUTTON (BOTTOM-RIGHT)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    heroTag: 'center',
                    mini: true,
                    onPressed: () {
                      mapController.move(
                        currentLocation!,
                        mapController.camera.zoom,
                      );
                      mapController.rotate(0); // NORTH-UP
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'center',
            child: const Icon(Icons.my_location),
            onPressed: () {
              mapController.move(currentLocation!, 16);
            },
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'north',
            child: const Icon(Icons.explore),
            onPressed: () {
              setState(() {
                followDirection = false;
              });
              mapController.rotate(0);
            },
          ),
        ],
      ),
    );
  }
}
