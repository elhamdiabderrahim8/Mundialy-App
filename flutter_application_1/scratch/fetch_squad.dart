import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // France squad - should have attackers
  final url = 'https://webws.365scores.com/web/squads/?appTypeId=5&langId=1&timezoneName=Europe/Paris&competitors=132';
  final response = await http.get(Uri.parse(url));
  final data = jsonDecode(response.body);
  final squads = data['squads'] as List?;
  
  if (squads != null && squads.isNotEmpty) {
    final athletes = squads[0]['athletes'] as List?;
    if (athletes != null) {
      print('=== ALL POSITIONS & AGES ===');
      for (var a in athletes) {
        final posId = a['position']?['id'];
        final posName = a['position']?['name'];
        final formPosId = a['formationPosition']?['id'];
        final formPosName = a['formationPosition']?['name'];
        final age = a['age'];
        final birthdate = a['birthdate'];
        print('${a["name"]}:');
        print('  position: id=$posId name=$posName');
        print('  formationPosition: id=$formPosId name=$formPosName');
        print('  age=$age, birthdate=$birthdate');
      }
    }
  }
}
