import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/sofa_direct_service.dart';

void main() {
  test('Debug SofaScore API Fetch', () async {
    // 10385750 is the 2022 World Cup Final: Argentina vs France (example ID)
    // 11352458 is maybe a 2026 match? Or just a random recent match.
    // Let's first test if we can fetch live matches.
    print('Fetching live matches...');
    final live = await SofaDirectService.fetchLiveMatches();
    print('Live matches fetched: ${live.length}');

    if (live.isNotEmpty) {
      final firstMatchId = live.first['fixture']['id'];
      print('Testing fetchMatchDetails for live match $firstMatchId...');
      final details = await SofaDirectService.fetchMatchDetails(firstMatchId);
      if (details == null) {
        print('FAILURE: fetchMatchDetails returned null for $firstMatchId');
      } else {
        print('SUCCESS: fetchMatchDetails returned data for $firstMatchId');
      }
    } else {
      print('No live matches to test.');
    }

    // Also test a specific 2026 match if we can find one.
    print('Fetching 2026 fixtures...');
    final fixtures = await SofaDirectService.fetchFixtures2026();
    print('Fixtures fetched: ${fixtures.length}');
    if (fixtures.isNotEmpty) {
      final fixtureId = fixtures.first['fixture']['id'];
      print('Testing fetchMatchDetails for fixture $fixtureId...');
      final details = await SofaDirectService.fetchMatchDetails(fixtureId);
      if (details == null) {
        print('FAILURE: fetchMatchDetails returned null for $fixtureId');
      } else {
        print('SUCCESS: fetchMatchDetails returned data for $fixtureId');
      }
    }
  });
}
