import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final double lat;
  final double lon;
  final String? city;
  LocationResult(this.lat, this.lon, this.city);
}

class LocationService {
  Future<LocationResult?> getCurrent() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) return null;

    final pos = await Geolocator.getCurrentPosition();

    String? city;
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality?.isNotEmpty == true ? p.locality : (p.administrativeArea ?? p.country);
      }
    } catch (_) {}

    return LocationResult(pos.latitude, pos.longitude, city);
  }
}
