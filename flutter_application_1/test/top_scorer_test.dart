import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/top_scorer.dart';

void main() {
  group('TopScorer', () {
    test('parse le format SofaScore 2026 plat', () {
      final scorer = TopScorer.fromApi({
        'player': {'id': 12994, 'name': 'Lionel Messi'},
        'team': {'id': 4819, 'name': 'Argentina'},
        'goals': 7,
        'assists': 3,
      }, 1);

      expect(scorer.playerId, 12994);
      expect(scorer.playerName, 'Lionel Messi');
      expect(scorer.teamName, 'Argentina');
      expect(scorer.goals, 7);
      expect(scorer.assists, 3);
    });

    test('parse le format API-Sports 2022', () {
      final scorer = TopScorer.fromApi({
        'player': {'name': 'Kylian Mbappé', 'photo': ''},
        'statistics': [
          {
            'team': {'id': 2, 'name': 'France', 'logo': ''},
            'goals': {'total': 8, 'assists': 2},
          },
        ],
      }, 1);

      expect(scorer.playerName, 'Kylian Mbappé');
      expect(scorer.teamName, 'France');
      expect(scorer.goals, 8);
      expect(scorer.assists, 2);
    });
  });
}
