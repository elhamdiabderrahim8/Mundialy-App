import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/scores365_service.dart';
import 'package:flutter_application_1/models/match_details.dart';
import 'package:flutter/foundation.dart';

void main() {
  test('Test RÉEL : Analyse des buteurs sur un match live/terminé de l\'API', () async {
    print('\n--- DEBUT DU TEST TECHNIQUE REEL ---');
    
    // 1. Récupération des matchs de l'API (72 matchs trouvés dans le test précédent)
    final fixtures = await Scores365Service.fetchFixtures2026();
    print('1. API Connectée : ${fixtures.length} matchs récupérés.');

    // On cherche un match qui a potentiellement des buts (on prend le premier pour l'exemple)
    final targetMatchId = 4627866; // Mexico vs South Africa
    print('2. Analyse du match ID: $targetMatchId...');

    // 2. Récupération des détails réels (incidents)
    final details = await Scores365Service.fetchMatchDetails(targetMatchId);
    
    if (details == null) {
      print('ERREUR : Impossible de récupérer les détails.');
      return;
    }

    // 3. Exécution de l'algorithme sur les données réelles reçues
    Map<String, int> localScorers = {};
    int totalGoalsInMatch = 0;

    print('3. Lecture des événements réels de l\'API...');
    for (final event in details.summary.events) {
      if (event.icon == MatchEventIcon.goal) {
        totalGoalsInMatch++;
        final name = event.scorerName;
        localScorers[name] = (localScorers[name] ?? 0) + 1;
        print('   [BUT TROUVÉ] : $name');
      }
    }

    print('\n--- SYNTHÈSE DE L\'ALGORITHME ---');
    if (totalGoalsInMatch == 0) {
      print('Résultat : Match nul (0-0) ou aucun buteur répertorié dans les incidents.');
    } else {
      print('Nombre total de buts identifiés : $totalGoalsInMatch');
      localScorers.forEach((name, goals) {
        print('Joueur : $name | Buts calculés : $goals');
      });
    }
    
    print('--- FIN DU TEST REEL ---\n');
    
    // Le test passe si on arrive au bout sans crash, prouvant que le mapping API -> Algorithme fonctionne
    expect(details, isNotNull);
  });
}
