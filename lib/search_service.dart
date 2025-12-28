import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SearchService {
  static Future<List<Map<String, dynamic>>> searchPlace(
      String query,
      LatLng userLocation, {
        String countryCode = 'np', // ✅ ADD THIS
      }) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
          '?q=$query'
          '&format=json'
          '&limit=5'
          '&countrycodes=$countryCode'
          '&viewbox='
          '${userLocation.longitude - 0.5},'
          '${userLocation.latitude - 0.5},'
          '${userLocation.longitude + 0.5},'
          '${userLocation.latitude + 0.5}'
          '&bounded=1',
    );

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'WakeUpSathi/1.0',
      },
    );

    final List data = jsonDecode(response.body);

    return data.map((e) {
      return {
        'name': e['display_name'],
        'lat': double.parse(e['lat']),
        'lon': double.parse(e['lon']),
      };
    }).toList();
  }
}
