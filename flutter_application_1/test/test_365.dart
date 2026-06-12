import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/scores365_service.dart';

void main() {
  test('Test 365Scores endpoints', () async {
    print('--- fetchFixtures2026 ---');
    final fixtures = await Scores365Service.fetchFixtures2026();
    print('Fixtures count: ${fixtures.length}');
    if (fixtures.isNotEmpty) {
      print(
        'First fixture: ${fixtures.first.homeTeam} vs ${fixtures.first.awayTeam} (ID: ${fixtures.first.id})',
      );
    }

    print('\n--- fetchLiveMatches ---');
    final live = await Scores365Service.fetchLiveMatches();
    print('Live matches: ${live.length}');

    print('\n--- fetchStandings2026 ---');
    final standings = await Scores365Service.fetchStandings2026();
    print('Standings groups: ${standings.length}');
    if (standings.isNotEmpty) {
      print(
        'First group: ${standings.first.groupName} with ${standings.first.teams.length} teams',
      );
    }

    print('\n--- fetchMatchDetails ---');
    // We use a known gameId from 365Scores: 4627866
    final details = await Scores365Service.fetchMatchDetails(4627866);
    if (details != null) {
      print(
        'Details for ${details.homeLineup.teamName} vs ${details.awayLineup.teamName}',
      );
      print('Lineups: ${details.homeLineup.players.length} starters for Home');
      print('Events: ${details.summary.events.length}');
      print('Stats: ${details.stats.length}');
    } else {
      print('Details returned null!');
    }
  });
}
