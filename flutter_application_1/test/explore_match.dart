import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url =
      'https://webws.365scores.com/web/game/?langId=1&apptype=5&gameId=4627866';
  final r = await http.get(Uri.parse(url));
  final d = jsonDecode(r.body);

  if (d['game'] != null) {
    final g = d['game'];
    print('Venue: ${g['venue']}');
    print('Officials: ${g['officials']}');

    if (g['homeCompetitor'] != null) {
      final home = g['homeCompetitor'];
      print('Home Color: ${home['color']}');
      print('Home Formation: ${home['lineups']?['formation']}');
    }

    // Check members for coaches
    final members = g['members'] as List? ?? [];
    for (var m in members) {
      if (m['positionId'] == null ||
          m['name'].toString().toLowerCase().contains('coach')) {
        print('Coach candidate: $m');
      }
    }

    // Added time in events
    final events = g['events'] as List? ?? [];
    for (var ev in events) {
      if (ev['addedTime'] != null && ev['addedTime'] > 0) {
        print(
          'Event with addedTime: ${ev['eventType']?['name']} at ${ev['gameTime']}+${ev['addedTime']}',
        );
      }
    }
  }
}
