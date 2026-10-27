---
id: di-get-it-scopes
title: get_it — scopes (pushNewScope) et scopes injectable
tags: [di, get_it, scope, session, lifecycle]
status: verified
updated: 2026-10-26
sources: [https://flutter-it.dev/documentation/get_it/scopes, https://pub.dev/documentation/get_it/latest/get_it/GetIt-class.html, https://pub.dev/packages/injectable]
links: [di-dispose-method, di-registration-annotations, di-micro-packages, ma-flutter-event-bus]
---
# Scopes get_it : une durée de vie pour un groupe d'objets

Un scope est une couche d'enregistrements empilée sur la précédente. Une registration du scope courant **masque** celle du même type dans les scopes inférieurs. `popScope()` dispose les objets du scope (dans l'ordre inverse d'enregistrement) et rétablit les précédents.

**API get_it 9.x :**
```dart
void pushNewScope({void init(GetIt getIt)?, String? scopeName,
                   ScopeDisposeFunc? dispose, bool isFinal});
Future<void> pushNewScopeAsync({Future<void> init(GetIt)?, String? scopeName,
                                ScopeDisposeFunc? dispose});
Future<void> popScope();
Future<void> dropScope(String scopeName);   // retire un scope nommé
Future<bool> popScopesTill(String name, {bool inclusive = true}); // false si nom absent
bool hasScope(String scopeName);  String? get currentScopeName;
```
- `isFinal: true` interdit toute registration après `init`.
- `getIt.onScopeChanged = (bool pushed) {...}` est appelé à chaque push et pop.

**Côté injectable :** `@Injectable(scope: 'voiceSession')` génère une méthode d'init dédiée, `await getIt.initVoiceSessionScope();`. Elle est async si le scope contient des `@preResolve`.

**Usage projet (opinion) :** un scope `voiceSession` contient runner, capture micro et lecteur audio.
- On le pousse au démarrage d'une conversation et on le dépile à la fin.
- Cela évite le bug du « singleton disposé non redémarrable » (proj-avw-risks #2).

## ⚠️ Pièges
- `popScope()` dépile le scope **du haut**, pas forcément celui qu'on vise. Pour un scope nommé, utiliser `dropScope(name)` ou `popScopesTill`.
- Un Bloc qui a reçu un objet du scope garde sa référence après le pop, alors que l'objet est disposé. Fermer le Bloc avant de dépiler.
- `currentScopeName` sur le scope de base : le code source get_it 9.3.0 renvoie `'baseScope'`, mais la page flutter-it.dev dit à un endroit `null`. Se fier au code, ou tester `hasScope` plutôt que le nom.
