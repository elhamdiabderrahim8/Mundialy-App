import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url2 = 'https://webws.365scores.com/web/squads/?appTypeId=5&langId=1&timezoneName=Europe/Paris&competitors=5053';
  final response2 = await http.get(Uri.parse(url2));
  final data2 = jsonDecode(response2.body);
  final squads2 = data2['squads'] as List?;
  if (squads2 != null && squads2.isNotEmpty) {
    for (var a in squads2[0]['athletes']) {
       if (a['formationPosition']?['id'] == 16 || a['formationPosition']?['name'] == 'Coach') {
           print(jsonEncode(a));
       }
    }
  }
}
