import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/match_details.dart';

void main() {
  group('MatchEvent', () {
    test('scorerName extrait le buteur sans passeur', () {
      const event = MatchEvent(
        minute: "23'",
        title: 'BUT !',
        description: 'T. Weah (pass. C. Ali)',
        icon: MatchEventIcon.goal,
        playerName: 'T. Weah',
        assistant: 'C. Ali',
      );
      expect(event.scorerName, 'T. Weah');
    });

    test('scorerName retire les parenthèses legacy', () {
      const event = MatchEvent(
        minute: "64'",
        title: 'BUT !',
        description: 'L. Messi (pass. A. Di Maria)',
        icon: MatchEventIcon.goal,
      );
      expect(event.scorerName, 'L. Messi');
    });

    test('scorerName retire (Penalty)', () {
      const event = MatchEvent(
        minute: "108'",
        title: 'BUT !',
        description: 'Lionel Messi (Penalty)',
        icon: MatchEventIcon.goal,
      );
      expect(event.scorerName, 'Lionel Messi');
    });

    test('fromApi conserve playerId et assistantId', () {
      final event = MatchEvent.fromApi({
        'incidentType': 'goal',
        'time': 64,
        'player': {'id': 12994, 'name': 'Lionel Messi'},
        'assist': {'id': 12345, 'name': 'Angel Di Maria'},
      });
      expect(event.playerId, 12994);
      expect(event.playerName, 'Lionel Messi');
      expect(event.assistantId, 12345);
      expect(event.assistant, 'Angel Di Maria');
    });
  });
}
