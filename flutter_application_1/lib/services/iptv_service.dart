import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modes de connexion
// ─────────────────────────────────────────────────────────────────────────────
enum IptvConnectionMode { xtream, m3u, playlistId, quickCode }

// ─────────────────────────────────────────────────────────────────────────────
// Modèle canal M3U parsé
// ─────────────────────────────────────────────────────────────────────────────
class IptvParsedChannel {
  final String name;
  final String logo;
  final String groupTitle;
  final String streamUrl;

  const IptvParsedChannel({
    required this.name,
    required this.logo,
    required this.groupTitle,
    required this.streamUrl,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Service principal
// ─────────────────────────────────────────────────────────────────────────────
class IptvService {
  // Clés SharedPreferences
  static const _keyServerUrl      = 'iptv_server_url';
  static const _keyUsername       = 'iptv_username';
  static const _keyPassword       = 'iptv_password';
  static const _keyM3uUrl         = 'iptv_m3u_url';
  static const _keyPlaylistId     = 'iptv_playlist_id';
  static const _keyPlaylistServer = 'iptv_playlist_server';
  static const _keyMode           = 'iptv_connection_mode';

  // État en mémoire
  String? _serverUrl;
  String? _username;
  String? _password;
  String? _m3uUrl;
  String? _playlistId;
  String? _playlistServer;
  IptvConnectionMode _mode = IptvConnectionMode.xtream;

  // Cache de la playlist parsée (mode M3U / Playlist ID)
  List<IptvParsedChannel> _parsedChannels = [];

  // ── Getters ───────────────────────────────────────────────────────────────
  IptvConnectionMode get currentMode => _mode;
  String? get playlistId     => _playlistId;
  String? get playlistServer => _playlistServer;

  bool get isConfigured {
    switch (_mode) {
      case IptvConnectionMode.xtream:
      case IptvConnectionMode.quickCode:
        return _serverUrl != null && _username != null && _password != null;
      case IptvConnectionMode.m3u:
      case IptvConnectionMode.playlistId:
        return _m3uUrl != null;
    }
  }

  // ── Initialisation ────────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_keyMode);
    if (modeStr != null) {
      _mode = IptvConnectionMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => IptvConnectionMode.xtream,
      );
    }
    _serverUrl      = prefs.getString(_keyServerUrl);
    _username       = prefs.getString(_keyUsername);
    _password       = prefs.getString(_keyPassword);
    _m3uUrl         = prefs.getString(_keyM3uUrl);
    _playlistId     = prefs.getString(_keyPlaylistId);
    _playlistServer = prefs.getString(_keyPlaylistServer);
  }

  // ── MODE 1 : Xtream Codes ─────────────────────────────────────────────────
  Future<bool> login(String serverUrl, String username, String password) async {
    serverUrl = _normalizeUrl(serverUrl);
    try {
      final uri = Uri.parse(
        '$serverUrl/player_api.php?username=$username&password=$password',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic> && data.containsKey('user_info')) {
          if ((data['user_info']['auth'] as int? ?? 0) == 1) {
            await _saveXtreamCreds(
              serverUrl, username, password, IptvConnectionMode.xtream,
            );
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('IPTV Xtream Login Error: $e');
    }
    return false;
  }

  // ── MODE 2 : URL M3U directe ──────────────────────────────────────────────
  Future<bool> loginWithM3uUrl(String url) async {
    url = _normalizeUrl(url);
    try {
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 &&
          resp.body.trimLeft().startsWith('#EXTM3U')) {
        final channels = _parseM3u(resp.body);
        if (channels.isNotEmpty) {
          await _saveM3uState(url, channels, IptvConnectionMode.m3u);
          return true;
        }
      }
    } catch (e) {
      debugPrint('IPTV M3U Login Error: $e');
    }
    return false;
  }

  // ── MODE 3 : Playlist ID (numérique) ─────────────────────────────────────
  /// Essaie plusieurs formats d'URL courants selon le serveur et l'ID fournis.
  /// Compatibles avec la plupart des panels IPTV (Xtream, Stalker, etc.)
  Future<bool> loginWithPlaylistId(String id, String server) async {
    server = _normalizeUrl(server);

    // Patterns testés dans l'ordre du plus courant au moins courant
    final patterns = [
      '$server/get.php?list_id=$id&type=m3u_plus&output=hls',
      '$server/get.php?list_id=$id&type=m3u_plus',
      '$server/get.php?list_id=$id&type=m3u',
      '$server/lists/$id.m3u8',
      '$server/lists/$id.m3u',
      '$server/playlist/$id.m3u8',
      '$server/playlist/$id.m3u',
      '$server/m3u/$id.m3u8',
      '$server/m3u/$id',
      '$server/$id.m3u8',
      '$server/$id.m3u',
    ];

    for (final url in patterns) {
      try {
        debugPrint('IPTV Playlist ID → tentative : $url');
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200 &&
            resp.body.trimLeft().startsWith('#EXTM3U')) {
          final channels = _parseM3u(resp.body);
          if (channels.isNotEmpty) {
            await _saveM3uState(url, channels, IptvConnectionMode.playlistId);
            // Mémoriser l'ID et le serveur pour affichage
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyPlaylistId, id);
            await prefs.setString(_keyPlaylistServer, server);
            _playlistId     = id;
            _playlistServer = server;
            return true;
          }
        }
      } catch (e) {
        debugPrint('IPTV Playlist ID → échec $url : $e');
      }
    }
    return false;
  }

  // ── MODE 4 : Code Rapide (base-64) ────────────────────────────────────────
  /// Code = base64( serverUrl|username|password )
  Future<bool> loginWithQuickCode(String code) async {
    try {
      final decoded =
          utf8.decode(base64Decode(code.trim().replaceAll(RegExp(r'\s'), '')));
      final parts = decoded.split('|');
      if (parts.length < 3) return false;
      final server = _normalizeUrl(parts[0]);
      final user   = parts[1];
      final pass   = parts.sublist(2).join('|');

      final uri = Uri.parse(
        '$server/player_api.php?username=$user&password=$pass',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic> && data.containsKey('user_info')) {
          if ((data['user_info']['auth'] as int? ?? 0) == 1) {
            await _saveXtreamCreds(
              server, user, pass, IptvConnectionMode.quickCode,
            );
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('IPTV Quick Code Login Error: $e');
    }
    return false;
  }

  /// Génère un code partageable depuis les identifiants Xtream actuels.
  String? generateQuickCode() {
    if (_serverUrl == null || _username == null || _password == null) return null;
    return base64Encode(utf8.encode('$_serverUrl|$_username|$_password'));
  }

  // ── Accès aux données ─────────────────────────────────────────────────────
  Future<List<dynamic>> getLiveCategories() async {
    if (!isConfigured) return [];

    // Mode M3U / Playlist ID → groupes extraits du cache parsé
    if (_mode == IptvConnectionMode.m3u ||
        _mode == IptvConnectionMode.playlistId) {
      if (_parsedChannels.isEmpty && _m3uUrl != null) {
        await loginWithM3uUrl(_m3uUrl!);
      }
      final seen = <String>{};
      final result = <Map<String, String>>[];
      for (final ch in _parsedChannels) {
        if (seen.add(ch.groupTitle)) {
          result.add({
            'category_id':   ch.groupTitle,
            'category_name': ch.groupTitle,
          });
        }
      }
      return result;
    }

    // Mode Xtream / QuickCode → API
    try {
      final uri = Uri.parse(
        '$_serverUrl/player_api.php?username=$_username'
        '&password=$_password&action=get_live_categories',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as List<dynamic>;
    } catch (e) {
      debugPrint('IPTV Categories Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getLiveStreams(String categoryId) async {
    if (!isConfigured) return [];

    if (_mode == IptvConnectionMode.m3u ||
        _mode == IptvConnectionMode.playlistId) {
      return _parsedChannels
          .where((c) => c.groupTitle == categoryId)
          .map((c) => <String, dynamic>{
                'name':        c.name,
                'stream_icon': c.logo,
                'stream_url':  c.streamUrl, // URL directe, pas d'ID Xtream
                'stream_id':   null,
              })
          .toList();
    }

    try {
      final uri = Uri.parse(
        '$_serverUrl/player_api.php?username=$_username'
        '&password=$_password&action=get_live_streams&category_id=$categoryId',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as List<dynamic>;
    } catch (e) {
      debugPrint('IPTV Streams Error: $e');
    }
    return [];
  }

  /// Génère l'URL de stream Xtream (mode Xtream / QuickCode uniquement).
  String getStreamUrl(int streamId, {bool useM3u8 = true}) {
    final ext = useM3u8 ? 'm3u8' : 'ts';
    return '$_serverUrl/live/$_username/$_password/$streamId.$ext';
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _keyServerUrl, _keyUsername, _keyPassword,
      _keyM3uUrl, _keyPlaylistId, _keyPlaylistServer, _keyMode,
    ]) {
      await prefs.remove(key);
    }
    _serverUrl      = null;
    _username       = null;
    _password       = null;
    _m3uUrl         = null;
    _playlistId     = null;
    _playlistServer = null;
    _parsedChannels = [];
    _mode           = IptvConnectionMode.xtream;
  }

  // ── Parser M3U interne ────────────────────────────────────────────────────
  List<IptvParsedChannel> _parseM3u(String content) {
    final channels = <IptvParsedChannel>[];
    final lines    = content.split('\n');
    String? name, logo, group;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF')) {
        name  = _attr(line, 'tvg-name') ??
                _attr(line, 'tvg-id')   ??
                _afterComma(line);
        logo  = _attr(line, 'tvg-logo') ?? '';
        group = _attr(line, 'group-title')?.replaceAll(';', ' ') ?? 'Général';
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (name != null && name.isNotEmpty) {
          channels.add(IptvParsedChannel(
            name:       name,
            logo:       logo ?? '',
            groupTitle: group ?? 'Général',
            streamUrl:  line,
          ));
        }
        name = logo = group = null;
      }
    }
    return channels;
  }

  String? _attr(String line, String attr) =>
      RegExp('$attr="([^"]*)"').firstMatch(line)?.group(1);

  String _afterComma(String line) {
    final idx = line.lastIndexOf(',');
    return idx != -1 ? line.substring(idx + 1).trim() : '';
  }

  // ── Helpers d'état ────────────────────────────────────────────────────────
  String _normalizeUrl(String url) {
    url = url.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.startsWith('http')) url = 'http://$url';
    return url;
  }

  Future<void> _saveXtreamCreds(
    String server, String user, String pass, IptvConnectionMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, server);
    await prefs.setString(_keyUsername, user);
    await prefs.setString(_keyPassword, pass);
    await prefs.setString(_keyMode, mode.name);
    await prefs.remove(_keyM3uUrl);
    await prefs.remove(_keyPlaylistId);
    await prefs.remove(_keyPlaylistServer);
    _serverUrl      = server;
    _username       = user;
    _password       = pass;
    _m3uUrl         = null;
    _playlistId     = null;
    _playlistServer = null;
    _parsedChannels = [];
    _mode           = mode;
  }

  Future<void> _saveM3uState(
    String url, List<IptvParsedChannel> channels, IptvConnectionMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyM3uUrl, url);
    await prefs.setString(_keyMode, mode.name);
    await prefs.remove(_keyServerUrl);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
    _m3uUrl         = url;
    _parsedChannels = channels;
    _serverUrl      = null;
    _username       = null;
    _password       = null;
    _mode           = mode;
  }
}
