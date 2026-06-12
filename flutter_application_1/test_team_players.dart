import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://api.sofascore.com/api/v1/team/4481/players');
  final response = await http.get(
    url,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Accept': 'application/json',
    },
  );
  print('Status code: ${response.statusCode}');
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['players'] != null) {
      print('Found ${data['players'].length} players');
      if ((data['players'] as List).isNotEmpty) {
        print('First player: ${data['players'][0]}');
      }
    } else {
      print('No players field. Response keys: ${data.keys}');
    }
  } else {
    print('Failed: ${response.body}');
  }
}
