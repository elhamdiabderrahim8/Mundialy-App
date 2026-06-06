import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/live_match.dart';

void main() {
  group('LiveMatch Model Tests (Fiabilité)', () {
    test('Parssage correct depuis JSON', () {
      final json = {
        'id': 12345,
        'homeTeam': {'name': 'France', 'nameCode': 'FRA', 'id': 1},
        'awayTeam': {'name': 'Argentina', 'nameCode': 'ARG', 'id': 2},
        'homeScore': {'display': 3},
        'awayScore': {'display': 3},
        'time': {'currentPeriodStartTimestamp': 1671375600},
        'status': {'code': 100, 'type': 'inprogress'}
      };

      final match = LiveMatch.fromJson(json);

      expect(match.id, 12345);
      expect(match.homeTeam, 'France');
      expect(match.awayTeam, 'Argentina');
      expect(match.scoreHome, 3);
      expect(match.scoreAway, 3);
      expect(match.isLive, true);
    });

    test('Gestion des données manquantes', () {
      final json = {
        'id': 12345,
        'homeTeam': {'name': 'France'},
        'awayTeam': {'name': 'Argentina'},
        'status': {'code': 0, 'type': 'notstarted'}
      };

      final match = LiveMatch.fromJson(json);

      expect(match.scoreHome, null);
      expect(match.scoreAway, null);
      expect(match.isLive, false);
      expect(match.isFinished, false);
    });
  });
}
