import 'dart:convert';
import 'dart:io';

void main() async {
  final baseParams = 'appTypeId=5&langId=15&timezoneName=Africa/Tunis&userCountryId=135';
  
  print('Testing API using games/current/... with batch');

  final url = Uri.parse('https://webws.365scores.com/web/games/current/?' + baseParams + '&competitions=588,572,67,7,11');
  try {
    final request = await HttpClient().getUrl(url);
    request.headers.set('User-Agent', 'Mozilla/5.0');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final data = jsonDecode(body);
    final games = data['games'] as List?;
    int count = games?.length ?? 0;
    print('[Batch 588,572,67,7,11] => ' + count.toString() + ' matchs trouves.');
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
