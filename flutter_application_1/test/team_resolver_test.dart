import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/live_match.dart';
import 'package:flutter_application_1/utils/team_resolver.dart';

void main() {
  group('TeamResolver', () {
    test('résout Tunisie via nom malgré ID api-sports', () {
      TeamResolver.indexMatches([
        const LiveMatch(
          id: '1',
          dateLabel: 'Mon 22 Nov',
          localTime: '14:00',
          city: 'City',
          homeTeam: 'Denmark',
          homeCode: 'DK',
          homeTeamId: 4775,
          awayTeam: 'Tunisia',
          awayCode: 'TN',
          awayTeamId: 4729,
          phaseLabel: 'Group',
        ),
      ]);

      expect(TeamResolver.resolve('Tunisia', hintId: 28), 4729);
      expect(
        TeamResolver.isSameTeam('Tunisia', 28, 'Tunisia', 4729),
        isTrue,
      );
    });
  });
}
