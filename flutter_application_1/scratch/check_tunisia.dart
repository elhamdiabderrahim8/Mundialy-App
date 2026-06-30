import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://webws.365scores.com/web/squads/?appTypeId=5&langId=1&timezoneName=Europe/Paris&competitors=5053';
  final response = await http.get(Uri.parse(url));
  final data = jsonDecode(response.body);
  final squads = data['squads'] as List?;
  
  if (squads != null && squads.isNotEmpty) {
    final athletes = squads[0]['athletes'] as List?;
    if (athletes != null) {
      for (var a in athletes) {
        if (a['formationPosition']?['name'] == 'Coach') {
          print('Coach: ${a["name"]}');
          print('Nationality Name: ${a["nationalityName"]}');
          print('Nationality ID: ${a["nationalityId"]}');
          print('All keys: ${a.keys}');
        }
      }
    }
  }
}
