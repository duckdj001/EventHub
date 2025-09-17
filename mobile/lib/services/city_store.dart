import 'package:shared_preferences/shared_preferences.dart';

class CityStore {
  static const _kCityName = 'city_name';
  static const _kCityLat = 'city_lat';
  static const _kCityLon = 'city_lon';

  String? name;
  double? lat;
  double? lon;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    name = p.getString(_kCityName);
    lat = p.getDouble(_kCityLat);
    lon = p.getDouble(_kCityLon);
  }

  Future<void> save({required String name, required double lat, required double lon}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCityName, name);
    await p.setDouble(_kCityLat, lat);
    await p.setDouble(_kCityLon, lon);
    this.name = name; this.lat = lat; this.lon = lon;
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCityName);
    await p.remove(_kCityLat);
    await p.remove(_kCityLon);
    name = lat = lon = null;
  }

  bool get hasCity => name != null && lat != null && lon != null;
}
