import 'dart:convert';
import 'dart:io';

void main() async {
  final baseParams = 'appTypeId=5&langId=15&timezoneName=Africa/Tunis&userCountryId=135';
  
  Future<void> testEndpoint(String endp) async {
    final url = Uri.parse('https://webws.365scores.com/web/' + endp + '?' + baseParams + '&competitions=7674');
    try {
      final request = await HttpClient().getUrl(url);
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();
      if (response.statusCode != 200) {
        print('[\$endp] => HTTP ' + response.statusCode.toString());
        return;
      }
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final games = data['games'] as List?;
      print('[\$endp] => Matches: ' + (games?.length ?? 0).toString());
    } catch (e) {
      print('[\$endp] => Error: ' + e.toString());
    }
  }

  await testEndpoint('games/results/');
  await testEndpoint('games/fixtures/');
  await testEndpoint('games/all/');
  await testEndpoint('results/');
}
