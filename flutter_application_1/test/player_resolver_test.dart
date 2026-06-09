import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/player_resolver.dart';

void main() {
  group('PlayerResolver', () {
    test('associe L. Messi à Lionel Messi', () {
      expect(
        PlayerResolver.namesMatch('L. Messi', 'Lionel Messi'),
        isTrue,
      );
    });

    test('associe T. Weah à Timothy Weah', () {
      expect(
        PlayerResolver.namesMatch('T. Weah', 'Timothy Weah'),
        isTrue,
      );
    });

    test('rejette des joueurs différents', () {
      expect(
        PlayerResolver.namesMatch('L. Messi', 'K. Mbappé'),
        isFalse,
      );
    });
  });
}
