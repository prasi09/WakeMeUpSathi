import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SearchService {
  static const _endpoint =
      'https://nominatim.openstreetmap.org/search';

  static Future<List<Map<String, dynamic>>> searchPlace(
      String query,
      LatLng userLocation,
      ) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '8',
      'addressdetails': '1',
      'countrycodes': 'np',

      // 📍 Bias towards user's location
      'lat': userLocation.latitude.toString(),
      'lon': userLocation.longitude.toString(),

      // 🇳🇵 Nepal bounding box (very important)
      'viewbox': '80.0586,26.347,88.2015,30.447',
      'bounded': '1',
    });

    final res = await http.get(
      uri,
      headers: {
        'User-Agent': 'WakeUpSathi/1.0',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Search failed');
    }

    final List data = json.decode(res.body);

    return data.map<Map<String, dynamic>>((e) {
      return {
        'name': e['display_name'],
        'lat': double.parse(e['lat']),
        'lon': double.parse(e['lon']),
      };
    }).toList();
  }
}
