import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse(
    'https://api.sofascore.com/api/v1/unique-tournament/16/season/58210/events/round/1',
  );
  final headers = {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'fr-FR,fr;q=0.9',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Infinix) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://www.sofascore.com/',
    'Origin': 'https://www.sofascore.com',
  };

  try {
    print('Fetching from $url...');
    final res = await http.get(url, headers: headers);
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      print('Success: ${res.body.substring(0, 100)}');
    } else {
      print('Error Body: ${res.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
