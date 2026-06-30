import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  test('Debug 365Scores penalties - Germany vs Paraguay (stageId=5)', () async {
    // Try a World Cup 2002 match ID - Germany vs Paraguay went to 1-0 regular time
    // Let's try to find a match with penaltiesScore in the API by querying match IDs we know have shootouts
    // 
    // We'll look for any match in 365Scores' competitions with penaltiesScore
    final gameId = 3907094; // Test a known Champions League match
    final url = Uri.parse(
      'https://webws.365scores.com/web/game/?appTypeId=5&langId=29&timezoneName=Europe/Paris&gameId=$gameId',
    );
    
    final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final g = data['game'];
      final home = g['homeCompetitor'] as Map<String, dynamic>? ?? {};
      final away = g['awayCompetitor'] as Map<String, dynamic>? ?? {};
      
      print('Score: ${home['score']} - ${away['score']}');
      print('Home penaltiesScore: ${home['penaltiesScore']}');
      print('Away penaltiesScore: ${away['penaltiesScore']}');
      print('Home hasPenalties: ${home.keys.toList()}');
      print('Status: ${g['statusText']}');
      
      final events = g['events'] as List? ?? [];
      print('Total events: ${events.length}');
      for (var ev in events) {
        final typeId = ev['eventType']?['id'];
        final subType = ev['eventType']?['subTypeName'];
        final stageId = ev['stageId'];
        final gameTime = ev['gameTime'];
        if (typeId == 1 || typeId == 13 || typeId == 14 || stageId == 5) {
          print('Event: typeId=$typeId, subType=$subType, stageId=$stageId, gameTime=$gameTime');
        }
      }
    } else {
      print('HTTP Error: ${response.statusCode}');
    }
  });
  
  test('Debug 365Scores - Check WC2026 match with shootout', () async {
    // Now let's look for Germany vs Paraguay 2026 in WC (it's the user's example)
    // Competition 5930 = FIFA World Cup 2026 (365Scores ID)
    // Let's search the results page
    final url = Uri.parse(
      'https://webws.365scores.com/web/games/results/?appTypeId=5&langId=29&timezoneName=Europe/Paris&competitions=5930&limit=100',
    );
    
    final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final games = data['games'] as List? ?? [];
      print('Total games: ${games.length}');
      for (var g in games) {
        final home = g['homeCompetitor'];
        final away = g['awayCompetitor'];
        final homeName = home['name'] ?? '';
        final awayName = away['name'] ?? '';
        final homeScore = home['score'];
        final awayScore = away['score'];
        final homePen = home['penaltiesScore'];
        final awayPen = away['penaltiesScore'];
        
        if (homePen != null || awayPen != null) {
          print('MATCH WITH PENALTIES: ID=${g['id']} $homeName($homePen) vs $awayName($awayPen) Score: $homeScore-$awayScore');
        }
        
        if ((homeName.contains('Germany') || awayName.contains('Germany')) &&
            (homeName.contains('Paraguay') || awayName.contains('Paraguay'))) {
          print('FOUND Germany vs Paraguay: ID=${g['id']} $homeName vs $awayName - Score: $homeScore-$awayScore - Pen: $homePen-$awayPen');
        }
      }
    } else {
      print('HTTP Error: ${response.statusCode}');
    }
  });
}
