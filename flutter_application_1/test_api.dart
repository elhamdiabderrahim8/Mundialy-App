import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseParams = 'appTypeId=5&langId=29&timezoneName=Europe%2FParis&userCountryId=135';
  final url = 'https://webws.365scores.com/web/games/allscores/?$baseParams&sportId=1';
  final response = await http.get(Uri.parse(url), headers: {
    'User-Agent': 'Mozilla/5.0',
    'Accept-Encoding': 'gzip, deflate, br'
  });
  
  final decoded = jsonDecode(response.body);
  if (decoded['games'] != null) {
    final games = decoded['games'] as List;
    for (final g in games) {
      if (g['statusGroup'] == 3) {
        print('Found Live Game:');
        print(g.keys.toList());
        print('gameTime: ${g['gameTime']}');
        print('gameTimeDisplay: ${g['gameTimeDisplay']}');
        print('gameTimeAndStatusDisplay: ${g['gameTimeAndStatusDisplay']}');
        print('actualActionTime: ${g['actualActionTime']}');
        print('startTime: ${g['startTime']}');
        print('playClock: ${g['playClock']}');
        print('clock: ${g['clock']}');
        print('lastActionTime: ${g['lastActionTime']}');
        break;
      }
    }
  }
}
