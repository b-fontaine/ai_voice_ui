---
id: test-integration-test
title: integration_test (SDK Flutter)
tags: [integration, e2e, integration_test, ci]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/testing/integration-tests, https://pub.dev/packages/material_ui]
links: [test-patrol, test-pyramid-flutter, test-coverage-ci]
---
# Tests bout en bout sur device ou desktop avec le package SDK `integration_test`

Doc consultée le 2026-10-26 (Flutter 3.47, page mise à jour le 2026-09-29).

```dart
// integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('démarre une session vocale', (tester) async {
    await tester.pumpWidget(const App());
    await tester.tap(find.byKey(const ValueKey('mic')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('listening')), findsOneWidget);
  });
}
```

## Mise en place
- Ajout : `flutter pub add "dev:integration_test:{sdk: flutter}"`.
- Lancer : `flutter test integration_test`, ou un seul fichier.
- Web :
  - `test_driver/integration_test.dart` avec `integrationDriver()`
  - lancer ChromeDriver au préalable (`chromedriver --port=4444`)
  - `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d chrome` (`-d web-server` en headless)

## Limites
- Pas d'accès à l'UI native : popup de permission micro, notifications. Pour cela, voir `test-patrol`.
- Linux CI : un serveur X est requis (`xvfb-run`), puis `flutter test integration_test -d linux -r github`.
- Android/iOS : vérifier que l'app a été retirée à la fin du test, sinon les tests suivants échouent.
- Firebase Test Lab : build debug, car un build `--release` n'inclut pas `package:integration_test`.

## ⚠️ Pièges
- L'exemple de la doc importe `package:material_ui/material_ui.dart` : Material est sorti du framework dans le package `material_ui` (Flutter >= 3.47.0 requis). Sur une version antérieure, garder `package:flutter/material.dart` (cf. `test-bdd-widget-test`).
