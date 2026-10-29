import 'package:shared_core/shared_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedClock implements AppClock {
  @override
  int nowUnixMs() => 1234;
}

void main() {
  group('AppClock', () {
    test('SystemClock renvoie l\'heure système en millisecondes', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final now = SystemClock().nowUnixMs();
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(now, inInclusiveRange(before, after));
    });

    test('un faux AppClock s\'utilise via l\'interface', () {
      final AppClock clock = _FixedClock();
      expect(clock.nowUnixMs(), 1234);
    });
  });
}
