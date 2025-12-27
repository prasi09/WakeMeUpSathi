import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;

  RouteResult(this.points, this.distanceKm, this.durationMin);
}

class RouteService {
  static Future<List<RouteResult>> getRoutes(
      LatLng start,
      LatLng end,
      ) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}'
          '?overview=full'
          '&geometries=geojson'
          '&alternatives=true',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Routing failed');
    }

    final data = json.decode(response.body);
    final routes = data['routes'];

    return routes.map<RouteResult>((r) {
      final coords = r['geometry']['coordinates'] as List;
      final points = coords
          .map<LatLng>((c) => LatLng(c[1], c[0]))
          .toList();

      return RouteResult(
        points,
        r['distance'] / 1000,
        r['duration'] / 60,
      );
    }).toList();
  }
}
