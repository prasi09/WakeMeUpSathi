import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';
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

class CompassWidget extends StatelessWidget {
  final double heading;

  const CompassWidget({super.key, required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -heading * pi / 180,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // N
            const Positioned(top: 12, child: Text('N', style: TextStyle(fontWeight: FontWeight.bold))),
            // S
            const Positioned(bottom: 6, child: Text('S')),
            // E
            const Positioned(right: 6, child: Text('E')),
            // W
            const Positioned(left: 6, child: Text('W')),

            // Needle
            Column(
              children: [
                Icon(Icons.arrow_drop_up, color: Colors.red, size: 30), // North
                Icon(Icons.arrow_drop_down, color: Colors.grey, size: 30,), // South
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _HomePageState extends State<HomePage> {
  final MapController mapController = MapController();

  LatLng? currentLocation;
  LatLng? destination;

  Timer? locationTimer;
  Timer? searchDebounce;
  StreamSubscription<CompassEvent>? compassSub;

  bool alerted = false;
  bool isSearching = false;
  bool isRouteLoading = false;

  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];

  List<RouteResult> routes = [];
  int selectedRoute = 0;

  double alertDistance = 500;
  double deviceHeading = 0;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    loadSettings();
    getLocation();
    startCompass();
  }

  void loadSettings() async {
    final s = await SettingsStorage.loadSettings();
    alertDistance = s.alertDistance;
  }

  void getLocation() async {
    Position pos = await LocationService.getCurrentLocation();
    setState(() {
      currentLocation = LatLng(pos.latitude, pos.longitude);
    });

    mapController.move(currentLocation!, 15);
    startTracking();
  }

  // ================= COMPASS =================
  void startCompass() {
    compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() {
          deviceHeading = event.heading!;
        });
      }
    });
  }

  // ================= TRACKING =================
  void startTracking() {
    locationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      Position pos = await LocationService.getCurrentLocation();

      setState(() {
        currentLocation = LatLng(pos.latitude, pos.longitude);
      });

      checkDistance();
    });
  }

  void checkDistance() async {
    if (destination == null || currentLocation == null || alerted) return;

    double distance = Geolocator.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      destination!.latitude,
      destination!.longitude,
    );

    if (distance <= alertDistance) {
      alerted = true;
      await AlarmService.play('alarm1');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AlarmPage()),
        );
      }
    }
  }

  // ================= FAST SEARCH =================
  void searchLocation(String query) {
    if (query.length < 3 || currentLocation == null) return;

    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => isSearching = true);

      final results = await SearchService.searchPlace(
        query,
        currentLocation!,
        countryCode: 'np',
      );

      setState(() {
        searchResults = results;
        isSearching = false;
      });
    });
  }

  // ================= ROUTES =================
  Future<void> fetchRoutes() async {
    if (currentLocation == null || destination == null) return;

    setState(() {
      isRouteLoading = true;
      routes.clear();
    });

    routes = await RouteService.getRoutes(
      currentLocation!,
      destination!,
    );

    setState(() => isRouteLoading = false);
    fitRoute();
  }

  void fitRoute() {
    if (routes.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(routes[selectedRoute].points);
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
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
      body: Stack(
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
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),

              // ROUTES
              if (routes.isNotEmpty)
                PolylineLayer(
                  polylines: routes.asMap().entries.map((e) {
                    return Polyline(
                      points: e.value.points,
                      strokeWidth: e.key == selectedRoute ? 5 : 3,
                      color: e.key == selectedRoute
                          ? Colors.blue
                          : Colors.grey,
                    );
                  }).toList(),
                ),

              // MARKERS
              MarkerLayer(
                markers: [
                  Marker(
                    point: currentLocation!,
                    width: 40,
                    height: 40,
                    child: Transform.rotate(
                      angle: deviceHeading * pi / 180,
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.blue,
                        size: 36,
                      ),
                    ),
                  ),
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

          // 🔍 SEARCH + SETTINGS (TOP)
          Positioned(
            top: 40,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search destination',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: searchLocation,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                      child: const Icon(Icons.settings),
                    ),
                  ],
                ),
                if (searchResults.isNotEmpty)
                  Material(
                    elevation: 1,
                    borderRadius: BorderRadius.circular(14),
                    child: ListView(
                      shrinkWrap: true,
                      children: searchResults.map((place) {
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
                            await fetchRoutes();
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ]


            ),
          ),

          // 🔽 SEARCH RESULTS
          // if (searchResults.isNotEmpty)
          //   Positioned(
          //     top: 100,
          //     left: 12,
          //     right: 12,
          //     child: Material(
          //       elevation: 6,
          //       borderRadius: BorderRadius.circular(14),
          //       child: ListView(
          //         shrinkWrap: true,
          //         children: searchResults.map((place) {
          //           return ListTile(
          //             title: Text(place['name']),
          //             onTap: () async {
          //               setState(() {
          //                 destination =
          //                     LatLng(place['lat'], place['lon']);
          //                 searchResults.clear();
          //                 searchController.text = place['name'];
          //                 alerted = false;
          //               });
          //               await fetchRoutes();
          //             },
          //           );
          //         }).toList(),
          //       ),
          //     ),
          //   ),

          // 🛣️ ROUTE CHIPS
          if (routes.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: routes.length,
                  itemBuilder: (_, i) {
                    final r = routes[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ChoiceChip(
                        label: Text(
                          '${r.durationMin.toStringAsFixed(0)} min • ${r.distanceKm.toStringAsFixed(1)} km',
                        ),
                        selected: selectedRoute == i,
                        onSelected: (_) {
                          setState(() => selectedRoute = i);
                          fitRoute();
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

          // 🧭 COMPASS
          Positioned(
            top: 120,
            right: 12,
            child: CompassWidget(heading: deviceHeading),
          ),

          // 🔄 RECENTER
          Positioned(
            bottom: 80,
            right: 12,
            child: FloatingActionButton(
              heroTag: 'recenter',
              mini: true,
              onPressed: () {
                if (currentLocation != null) {
                  mapController.move(
                    currentLocation!,
                    mapController.camera.zoom,
                  );
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // 🧭 NORTH ALIGN
          Positioned(
            bottom: 20,
            right: 12,
            child: FloatingActionButton(
              heroTag: 'north',
              mini: true,
              onPressed: () {
                mapController.rotate(0);
              },
              child: const Icon(Icons.explore),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    searchDebounce?.cancel();
    compassSub?.cancel();
    super.dispose();
  }
}
