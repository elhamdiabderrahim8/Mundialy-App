import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

// Simulated imports for the test script
const Map<int, String> nationality365IdToCode = {
  5: 'FR',
  122: 'SA',
};

String resolveNationalityId(int nationalityId) {
  return nationality365IdToCode[nationalityId] ?? '';
}

void main() async {
  // Let's hit the Tunisia API directly to see what coach data is retrieved.
  final url = 'https://webws.365scores.com/web/squads/?appTypeId=5&langId=1&timezoneName=Europe/Paris&competitors=122';
  final response = await http.get(Uri.parse(url));
  final data = jsonDecode(response.body);
  
  // Try competitors=122 (Saudi Arabia) to see if Herve Renard is there.
  print('checking 122');
  final squads1 = data['squads'] as List?;
  if (squads1 != null && squads1.isNotEmpty) {
    for (var a in squads1[0]['athletes']) {
       if (a['formationPosition']?['id'] == 16 || a['formationPosition']?['name'] == 'Coach' || a['formationPosition']?['name'] == 'Manager') {
           print("SA Coach: ${a['name']} | natName: ${a['nationalityName']} | natId: ${a['nationalityId']}");
       }
    }
  }

  // Also check Tunisia
  print('checking 5053');
  final url2 = 'https://webws.365scores.com/web/squads/?appTypeId=5&langId=1&timezoneName=Europe/Paris&competitors=5053';
  final response2 = await http.get(Uri.parse(url2));
  final data2 = jsonDecode(response2.body);
  final squads2 = data2['squads'] as List?;
  if (squads2 != null && squads2.isNotEmpty) {
    for (var a in squads2[0]['athletes']) {
       if (a['formationPosition']?['id'] == 16 || a['formationPosition']?['name'] == 'Coach' || a['formationPosition']?['name'] == 'Manager') {
           print("TUN Coach: ${a['name']} | natName: ${a['nationalityName']} | natId: ${a['nationalityId']}");
       }
    }
  }
}
