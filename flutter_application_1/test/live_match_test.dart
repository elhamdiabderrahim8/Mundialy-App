import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/live_match.dart';

void main() {
  group('LiveMatch Model Tests (Fiabilité)', () {
    test('Parssage correct depuis JSON', () {
      final json = {
        'id': '12345',
        'date_label': '20 Nov',
        'local_time': '17:00',
        'city': 'Doha',
        'home_team': 'France',
        'home_code': 'FRA',
        'away_team': 'Argentina',
        'away_code': 'ARG',
        'phase_label': 'Final',
        'score_home': 3,
        'score_away': 3,
        'is_live': true,
        'status_short': 'HT'
      };

      final match = LiveMatch.fromJson(json);

      expect(match.id, '12345');
      expect(match.homeTeam, 'France');
      expect(match.awayTeam, 'Argentina');
      expect(match.scoreHome, 3);
      expect(match.scoreAway, 3);
      expect(match.isLive, true);
    });

    test('Gestion des données manquantes', () {
      final json = {
        'id': '12345',
        'date_label': '20 Nov',
        'local_time': '17:00',
        'city': 'Doha',
        'home_team': 'France',
        'home_code': 'FRA',
        'away_team': 'Argentina',
        'away_code': 'ARG',
        'phase_label': 'Final',
      };

      final match = LiveMatch.fromJson(json);

      expect(match.scoreHome, null);
      expect(match.scoreAway, null);
      expect(match.isLive, false);
    });
  });
}
