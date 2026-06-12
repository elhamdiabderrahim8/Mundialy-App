import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url =
      'https://webws.365scores.com/web/games/current/?appTypeId=5&langId=29&timezoneName=Europe/Paris&userCountryId=35';
  final response = await http.get(Uri.parse(url));
  final json = jsonDecode(response.body);

  final games = json['games'] as List? ?? [];
  for (var game in games) {
    if (game['status']?['id'] == 3) {
      // ended
      final gameId = game['id'];
      final statsUrl =
          'https://webws.365scores.com/web/game/stats/?appTypeId=5&langId=29&games=$gameId';
      final statsResp = await http.get(Uri.parse(statsUrl));
      final statsJson = jsonDecode(statsResp.body);

      final comps = statsJson['competitors'] ?? [];
      for (var comp in comps) {
        final line = comp['lineups'];
        if (line != null &&
            line['members'] != null &&
            line['members'].isNotEmpty) {
          print("Found match $gameId, team ${comp['name']}");
          for (var m in line['members']) {
            print(
              "Member: ${m['name']} - yardFormation: ${m['yardFormation']}",
            );
          }
          return;
        }
      }
    }
  }
}
