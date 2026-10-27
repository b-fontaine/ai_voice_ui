---
id: test-patrol
title: Patrol — E2E avec automatisation native
tags: [integration, e2e, patrol, native, permissions]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/patrol, https://pub.dev/packages/patrol_cli, https://patrol.leancode.co/documentation, https://patrol.leancode.co/documentation/compatibility-table, https://pub.dev/packages/bdd_widget_test]
links: [test-integration-test, test-bdd-build-yaml, test-pyramid-flutter]
---
# Patrol : nécessaire dès qu'un test touche l'UI native (permission micro)

Versions observées le 2026-10-26 :
- **`patrol` 4.10.0** (leancode.co, publiée le 2026-09-15) ; une 4.11.0-dev.1 existe (2026-09-20).
- **`patrol_cli` 4.8.0** (2026-09-15), à installer avec `dart pub global activate patrol_cli`.
- Plateformes : Android, iOS, macOS, web.

```dart
patrolTest('accepte la permission micro et démarre la session', ($) async {
  await $.pumpWidgetAndSettle(const App());
  await $(#mic).tap();
  if (await $.platform.mobile.isPermissionDialogVisible()) {
    await $.platform.mobile.grantPermissionWhenInUse();
  }
});
```

## Points clés
- **Finders `$` :** recherche par `#key`, par type ou par texte, chaînables : `$(Scaffold).$(#box1).$('Log in')`.
- **Outillage CLI :**
  - `patrol doctor` vérifie la toolchain
  - `patrol test -t patrol_test/x_test.dart` lance un test
  - les tests vivent dans `patrol_test/` par défaut (`test_directory` dans `pubspec.yaml`)
- **Bundle de tests :** `test_bundle.dart` est généré : l'ajouter au `.gitignore`, comme `.patrol.env`.
- **Couplage avec bdd_widget_test :** options `testMethodName: patrolTest`, `testerName: $`, `testerType: PatrolIntegrationTester`, `includeIntegrationTestBinding: false`, plus les imports via `customHeaders`.

## ⚠️ Pièges
- Compatibilité : table officielle sur la doc (`patrol_cli` 4.7.0+ ↔ `patrol` 4.9.0+, Flutter >= 3.32.0). Certaines fonctions (découverte au build iOS, screenshots natifs) exigent la paire `patrol_cli` 4.8.0 / `patrol` 4.10.0. Épingler les deux en CI.
- Permissions : `$.platform.mobile` expose aussi `grantPermissionOnlyThisTime()` et `denyPermission()` ; les garder derrière `isPermissionDialogVisible()` (lu dans `mobile_automator.dart` de la 4.10.0).
- iOS/macOS : depuis Patrol 4.7.0, le support de Swift Package Manager demande quelques ajustements de setup.
