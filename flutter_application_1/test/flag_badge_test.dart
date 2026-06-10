import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/country_flags.dart';
import 'package:flutter_application_1/widgets/nation_flag_badge.dart';

void main() {
  group('NationFlagBadge flag source', () {
    test('uses flagcdn for alpha2 codes', () {
      expect(
        NationFlagBadge.resolveFlagUrl('FR'),
        'https://flagcdn.com/w160/fr.png',
      );
    });

    test('uses flagcdn for alpha3 codes', () {
      expect(
        NationFlagBadge.resolveFlagUrl('USA'),
        'https://flagcdn.com/w160/us.png',
      );
    });

    test('uses flagcdn for subdivision codes', () {
      expect(
        NationFlagBadge.resolveFlagUrl('GB-ENG'),
        'https://flagcdn.com/w160/gb-eng.png',
      );
    });

    test('resolves team names to flagcdn through the shared country mapping', () {
      final countryCode = resolveCountryCode('England');

      expect(countryCode, 'GB-ENG');
      expect(
        NationFlagBadge.resolveFlagUrl(countryCode),
        'https://flagcdn.com/w160/gb-eng.png',
      );
    });
  });
}