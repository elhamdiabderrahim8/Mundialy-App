import 'dart:convert';
import 'dart:io';

void main() async {
  final baseParams = 'appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135';
  
  Future<void> testComp(int id, String name) async {
    final url = Uri.parse('https://webws.365scores.com/web/games/?$baseParams&competitions=$id');
    try {
      final request = await HttpClient().getUrl(url);
      request.headers.set('User-Agent', 'Dart/3.0 (dart:io)');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final games = data['games'] as List?;
      print('[$name (ID: $id)] => HTTP ${response.statusCode} | Games count: ${games?.length ?? 0}');
    } catch (e) {
      print('[$name (ID: $id)] => Error: $e');
    }
  }

  await testComp(67, 'CAN');
  await testComp(572, 'EURO');
  await testComp(5930, 'World Cup');
}
