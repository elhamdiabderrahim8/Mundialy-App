import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://webws.365scores.com/web/competitors/?appTypeId=5&langId=1&timezoneName=Europe/Paris&competitors=100-200,5000-5100';
  final response = await http.get(Uri.parse(url));
  final data = jsonDecode(response.body);
  final comps = data['competitors'] as List?;
  
  if (comps != null) {
    for (var c in comps) {
      if (c['name'].toString().toLowerCase().contains('tunisia')) {
        print('Tunisia ID: ${c["id"]}');
      }
    }
  }
}
