import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Saudi Arabia id is 122, but let's just search the competitors endpoint or something
  // Actually, we can search by athlete ID if we know it.
  // Or just query the search endpoint.
  final url = 'https://webws.365scores.com/web/search/?appTypeId=5&langId=1&timezoneName=Europe/Paris&q=Herve%20Renard';
  final response = await http.get(Uri.parse(url));
  final data = jsonDecode(response.body);
  final competitors = data['competitors'] as List?;
  if (competitors != null) {
    for (var c in competitors) {
      print('Competitor: ${c["name"]} (ID: ${c["id"]})');
    }
  }
}
