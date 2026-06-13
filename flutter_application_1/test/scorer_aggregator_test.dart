import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/match_details.dart';
import 'package:flutter_application_1/models/top_scorer.dart';
import 'dart:convert';

void main() {
  test('Algorithme d\'agrégation des buteurs', () {
    // Simulation de données de match
    final List<MatchEvent> events = [
      MatchEvent(
        minute: "10'",
        title: "BUT",
        description: "L. Messi",
        icon: MatchEventIcon.goal,
        teamName: "Argentina",
        playerName: "Lionel Messi",
        playerId: 12994,
      ),
      MatchEvent(
        minute: "45'",
        title: "BUT",
        description: "L. Messi",
        icon: MatchEventIcon.goal,
        teamName: "Argentina",
        playerName: "Lionel Messi",
        playerId: 12994,
      ),
      MatchEvent(
        minute: "60'",
        title: "BUT",
        description: "K. Mbappe",
        icon: MatchEventIcon.goal,
        teamName: "France",
        playerName: "Kylian Mbappe",
        playerId: 2,
      ),
    ];

    // Simulation de l'algorithme (Map locale pour le test)
    Map<String, dynamic> playerMap = {};

    for (final event in events) {
      if (event.icon == MatchEventIcon.goal) {
        final name = event.scorerName;
        final team = event.teamName;
        final pId = event.playerId ?? 0;
        final key = pId > 0 ? '$pId' : '${name}_$team';

        if (playerMap.containsKey(key)) {
          playerMap[key]['goals'] = (playerMap[key]['goals'] ?? 0) + 1;
        } else {
          playerMap[key] = {
            'id': pId,
            'name': name,
            'team': team,
            'goals': 1,
          };
        }
      }
    }

    expect(playerMap.length, 2);
    expect(playerMap['12994']['goals'], 2);
    expect(playerMap['2']['goals'], 1);
  });
}
