import 'dart:convert';
import 'dart:io';

void main() async {
  final baseParams = 'appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135';
  
  // Euro=572, CAN=67, WC=5930, Friendly=64, U20 Friendly=5560
  final compIds = [572, 67, 5930, 64, 5560, 5634, 570, 7150, 7152]; 
  
  final now = DateTime.now();
  final realNow = DateTime(now.year - 2, now.month, now.day);
  final startStr = "${realNow.subtract(const Duration(days: 15)).day.toString().padLeft(2, '0')}/${realNow.subtract(const Duration(days: 15)).month.toString().padLeft(2, '0')}/${realNow.subtract(const Duration(days: 15)).year}";
  final endStr = "${realNow.add(const Duration(days: 15)).day.toString().padLeft(2, '0')}/${realNow.add(const Duration(days: 15)).month.toString().padLeft(2, '0')}/${realNow.add(const Duration(days: 15)).year}";

  print('Testing API from ' + startStr + ' to ' + endStr + '...');

  int totalMatches = 0;

  for (final id in compIds) {
    final url = Uri.parse('https://webws.365scores.com/web/games/?' + baseParams + '&competitions=' + id.toString() + '&startDate=' + startStr + '&endDate=' + endStr);
    try {
      final request = await HttpClient().getUrl(url);
      request.headers.set('User-Agent', 'Dart/3.0 (dart:io)');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final games = data['games'] as List?;
      int count = games?.length ?? 0;
      totalMatches += count;
      if (count > 0) {
        print('[Comp ID: ' + id.toString() + '] => ' + count.toString() + ' matchs trouves.');
      }
    } catch (e) {
      print('Error: ' + e.toString());
    }
  }
  
  print('Total des matchs recuperes: ' + totalMatches.toString());
}
