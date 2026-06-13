import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/match_details.dart';
import 'package:flutter_application_1/models/top_scorer.dart';

void main() {
  test('DEBUG : Simulation et Affichage des résultats de l\'algorithme', () {
    print('\n--- DEBUT DU TEST DE L\'ALGORITHME ---');
    
    // Simulation d'une série de matchs réels (exemple Coupe du Monde)
    final List<MatchEvent> simulatedEvents = [
      // Match 1 : Argentine vs France
      MatchEvent(minute: "23'", title: "BUT", description: "L. Messi (P)", icon: MatchEventIcon.goal, teamName: "Argentina", playerName: "Lionel Messi", playerId: 12994),
      MatchEvent(minute: "36'", title: "BUT", description: "A. Di Maria", icon: MatchEventIcon.goal, teamName: "Argentina", playerName: "Angel Di Maria", playerId: 1234),
      MatchEvent(minute: "80'", title: "BUT", description: "K. Mbappe (P)", icon: MatchEventIcon.goal, teamName: "France", playerName: "Kylian Mbappe", playerId: 2),
      MatchEvent(minute: "81'", title: "BUT", description: "K. Mbappe", icon: MatchEventIcon.goal, teamName: "France", playerName: "Kylian Mbappe", playerId: 2),
      MatchEvent(minute: "108'", title: "BUT", description: "L. Messi", icon: MatchEventIcon.goal, teamName: "Argentina", playerName: "Lionel Messi", playerId: 12994),
      MatchEvent(minute: "118'", title: "BUT", description: "K. Mbappe (P)", icon: MatchEventIcon.goal, teamName: "France", playerName: "Kylian Mbappe", playerId: 2),
      
      // Match 2 : France vs Maroc
      MatchEvent(minute: "5'", title: "BUT", description: "T. Hernandez", icon: MatchEventIcon.goal, teamName: "France", playerName: "Theo Hernandez", playerId: 567),
      MatchEvent(minute: "79'", title: "BUT", description: "R. Kolo Muani", icon: MatchEventIcon.goal, teamName: "France", playerName: "Randal Kolo Muani", playerId: 890),
    ];

    Map<String, dynamic> playerMap = {};

    print('Analyse des événements en cours...');
    for (final event in simulatedEvents) {
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
        print(' > BUT détecté : $name ($team)');
      }
    }

    // Conversion pour affichage trié
    final List<TopScorer> list = playerMap.values.map((v) {
      return TopScorer(
        playerId: v['id'] ?? 0,
        playerName: v['name'] ?? '',
        teamName: v['team'] ?? '',
        teamCode: '',
        goals: v['goals'] ?? 0,
        matches: 0,
        assists: 0,
      );
    }).toList();

    list.sort((a, b) => b.goals.compareTo(a.goals));

    print('\n--- CLASSEMENT DES BUTEURS RÉCUPÉRÉS ---');
    for (int i = 0; i < list.length; i++) {
      print('${i + 1}. ${list[i].playerName.padRight(20)} | Équipe: ${list[i].teamName.padRight(12)} | Buts: ${list[i].goals}');
    }
    print('--- FIN DU TEST ---\n');

    expect(list.first.playerName, 'Kylian Mbappe');
    expect(list.first.goals, 3);
    expect(list[1].playerName, 'Lionel Messi');
    expect(list[1].goals, 2);
  });
}
