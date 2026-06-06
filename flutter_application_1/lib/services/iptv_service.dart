import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class IptvService {
  static const String _keyServerUrl = 'iptv_server_url';
  static const String _keyUsername = 'iptv_username';
  static const String _keyPassword = 'iptv_password';

  String? _serverUrl;
  String? _username;
  String? _password;

  bool get isConfigured =>
      _serverUrl != null && _username != null && _password != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_keyServerUrl);
    _username = prefs.getString(_keyUsername);
    _password = prefs.getString(_keyPassword);
  }

  Future<bool> login(String serverUrl, String username, String password) async {
    // Remove trailing slash if present
    if (serverUrl.endsWith('/')) {
      serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }
    // Ensure starts with http
    if (!serverUrl.startsWith('http')) {
      serverUrl = 'http://$serverUrl';
    }

    try {
      final url = Uri.parse(
        '$serverUrl/player_api.php?username=$username&password=$password',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('user_info')) {
          final userInfo = data['user_info'];
          if (userInfo['auth'] == 1) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyServerUrl, serverUrl);
            await prefs.setString(_keyUsername, username);
            await prefs.setString(_keyPassword, password);

            _serverUrl = serverUrl;
            _username = username;
            _password = password;
            return true;
          }
        }
      }
    } catch (e) {
      print('IPTV Login Error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
    _serverUrl = null;
    _username = null;
    _password = null;
  }

  Future<List<dynamic>> getLiveCategories() async {
    if (!isConfigured) return [];
    try {
      final url = Uri.parse(
        '$_serverUrl/player_api.php?username=$_username&password=$_password&action=get_live_categories',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      print('IPTV Categories Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getLiveStreams(String categoryId) async {
    if (!isConfigured) return [];
    try {
      final url = Uri.parse(
        '$_serverUrl/player_api.php?username=$_username&password=$_password&action=get_live_streams&category_id=$categoryId',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      print('IPTV Streams Error: $e');
    }
    return [];
  }

  // Permet de choisir M3U8 ou TS. La plupart des players mobiles préfèrent le M3U8 (HLS).
  String getStreamUrl(int streamId, {bool useM3u8 = true}) {
    final extension = useM3u8 ? 'm3u8' : 'ts';
    return '$_serverUrl/live/$_username/$_password/$streamId.$extension';
  }
}
