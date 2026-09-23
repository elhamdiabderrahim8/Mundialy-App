import 'dart:convert';
import 'dart:io';

void main() async {
  final baseParams = 'appTypeId=5&langId=15&timezoneName=Africa/Tunis&userCountryId=135';
  
  final compIds = [588, 572, 67, 7, 11]; // CAN Qualifs, Euro, CAN, Premier League, La Liga
  
  print('Testing API using games/current/...');

  for (final id in compIds) {
    final url = Uri.parse('https://webws.365scores.com/web/games/current/?' + baseParams + '&competitions=' + id.toString());
    try {
      final request = await HttpClient().getUrl(url);
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
      request.headers.set('Referer', 'https://www.365scores.com/');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final games = data['games'] as List?;
      int count = games?.length ?? 0;
      print('[Comp ID: ' + id.toString() + '] => ' + count.toString() + ' matchs trouves.');
    } catch (e) {
      print('Error: ' + e.toString());
    }
  }
}
