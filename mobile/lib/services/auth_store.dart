import 'package:shared_preferences/shared_preferences.dart';


class AuthStore {
  String? token;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    print('Loaded token: $token');   // добавь для отладки
  }

  Future<void> save(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', t);
    token = t;
    print('Saved token: $t');
  }
}
