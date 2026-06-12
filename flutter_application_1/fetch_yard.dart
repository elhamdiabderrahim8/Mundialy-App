import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url =
      'https://webws.365scores.com/web/game/stats/?appTypeId=5&langId=29&timezoneName=Europe/Paris&userCountryId=35&games=4697696';
  final response = await http.get(Uri.parse(url));
  final json = jsonDecode(response.body);

  final lineups = json['statistics'] ?? [];
  final comps = json['competitors'] ?? [];

  for (var comp in comps) {
    print("Competitor: ${comp['name']}");
    final line = comp['lineups'];
    if (line != null && line['members'] != null) {
      for (var m in line['members']) {
        print("Member: ${m['name']} - yardFormation: ${m['yardFormation']}");
      }
    }
  }
}
