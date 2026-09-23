import 'dart:convert';
import 'dart:io';

void main() async {
  final baseParams = 'appTypeId=5&langId=15&timezoneName=Africa/Tunis&userCountryId=135';
  final url = Uri.parse('https://webws.365scores.com/web/games/current/?' + baseParams + '&competitions=7674');
  try {
    final request = await HttpClient().getUrl(url);
    request.headers.set('User-Agent', 'Mozilla/5.0');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final data = jsonDecode(body);
    final games = data['games'] as List?;
    print('Matches returned: ' + (games?.length ?? 0).toString());
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
