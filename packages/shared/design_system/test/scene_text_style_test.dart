import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

void main() {
  testWidgets(
    'sceneTextStyle reprend la famille ambiante et garde taille et graisse',
    (tester) async {
      late TextStyle resolved;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Ambiante',
              fontFamilyFallback: <String>['Secours'],
            ),
            child: Builder(
              builder: (context) {
                resolved = sceneTextStyle(
                  context,
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolved.fontFamily, 'Ambiante');
      expect(resolved.fontFamilyFallback, <String>['Secours']);
      expect(resolved.fontSize, 26);
      expect(resolved.fontWeight, FontWeight.w700);
    },
  );
}
