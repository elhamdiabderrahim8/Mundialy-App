import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://webws.365scores.com/web/squads/?appTypeId=5&langId=1&timezoneName=Europe/Paris&competitors=122';
  final response = await http.get(Uri.parse(url));
  final data = jsonDecode(response.body);
  final squads = data['squads'] as List?;
  
  if (squads != null && squads.isNotEmpty) {
    final athletes = squads[0]['athletes'] as List?;
    if (athletes != null) {
      for (var a in athletes) {
        final formPos = a['formationPosition']?['name']?.toString().toLowerCase() ?? '';
        if (formPos.contains('coach') || formPos.contains('manager') || a['formationPosition']?['id'] == 16) {
          print('Staff: ${a["name"]}');
          print('Formation Pos: $formPos');
          print('Nationality ID: ${a["nationalityId"]}');
        }
      }
    }
  }
}
