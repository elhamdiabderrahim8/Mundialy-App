import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== TEST URL WITH SPORTS=1 ===');
  final url1 =
      'https://webws.365scores.com/web/games/?appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135&competitions=5930&startDate=11/06/2026&endDate=19/07/2026&sports=1';
  final r1 = await http.get(Uri.parse(url1));
  final d1 = jsonDecode(r1.body);
  print('games count: ${d1['games']?.length}');

  print('=== TEST URL WITHOUT SPORTS=1 ===');
  final url2 =
      'https://webws.365scores.com/web/games/?appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135&competitions=5930&startDate=11/06/2026&endDate=19/07/2026';
  final r2 = await http.get(Uri.parse(url2));
  final d2 = jsonDecode(r2.body);
  print('games count: ${d2['games']?.length}');
}
