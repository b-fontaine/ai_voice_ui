import 'package:feature_canvas/src/catalog/fr_percent.dart';
import 'package:flutter_test/flutter_test.dart';

/// `parseFrPercent` lit « 99,43 % » et « ≥ 99,50 % » et refuse le reste
/// (pdr-0088 F3) : jamais appelée sur `delta` ni sur `statusLabel`.
void main() {
  group('parseFrPercent accepte', () {
    const accepted = <String, double>{
      '99,43 %': 99.43,
      '99,57 %': 99.57,
      '99,5 %': 99.5,
      '100 %': 100,
      '0,25 %': 0.25,
      '99,43%': 99.43,
      '≥ 99,50 %': 99.5,
      '≥99,50 %': 99.5,
      '  99,43 %  ': 99.43,
      // espace insécable, espace fine insécable, espace fine
      '99,43 %': 99.43,
      '99,43 %': 99.43,
      '99,43 %': 99.43,
      '≥ 99,50 %': 99.5,
    };
    for (final MapEntry<String, double> entry in accepted.entries) {
      test('« ${entry.key} »', () {
        expect(parseFrPercent(entry.key), closeTo(entry.value, 1e-9));
      });
    }
  });

  group('parseFrPercent refuse', () {
    const refused = <String>[
      '',
      ' ',
      'n/d',
      '99,43',
      '%',
      '99.43 %',
      '99,43 pt',
      '−0,54 pt',
      '-0,54 %',
      '≤ 99,50 %',
      '> 99,50 %',
      '≥ %',
      '99,43 % (3.3 : 99,71 %)',
      '99,,43 %',
      ',43 %',
      'À risque',
      'Bloquant',
    ];
    for (final String text in refused) {
      test('« $text »', () {
        expect(parseFrPercent(text), isNull);
      });
    }
  });

  group('FrPercent.tryParse découpe le texte sans le modifier', () {
    test('valeur : nombre puis suffixe, la concaténation redonne le texte', () {
      final FrPercent? parsed = FrPercent.tryParse('99,43 %');
      expect(parsed, isNotNull);
      expect(parsed!.number, '99,43');
      expect(parsed.suffix, ' %');
      expect('${parsed.prefix}${parsed.number}${parsed.suffix}', '99,43 %');
      expect(parsed.value, closeTo(99.43, 1e-9));
    });

    test('seuil : le préfixe garde le signe et l\'espace', () {
      final FrPercent? parsed = FrPercent.tryParse('≥ 99,50 %');
      expect(parsed!.prefix, '≥ ');
      expect(parsed.number, '99,50');
      expect(parsed.suffix, ' %');
    });

    test('texte illisible : null', () {
      expect(FrPercent.tryParse('n/d'), isNull);
    });
  });
}
