---
id: genui-test-a2a-roundtrip
title: Tester genui_a2a contre un vrai serveur dans testWidgets (pièges HTTP et FakeAsync)
tags: [genui, a2a, testing, widget-test, fake-async, http]
status: verified
updated: 2026-10-29
sources: [https://pub.dev/packages/genui_a2a, https://api.flutter.dev/flutter/flutter_test/TestWidgetsFlutterBinding-class.html]
links: [genui-a2a-connector, genui-test-surface-controller, test-fake-async-streams, proto-a2a-go-v03-compat]
---
# Un test de bout en bout `A2uiAgentConnector` ↔ agent réel, sous `testWidgets`

Vérifié le 2026-10-29 (`genui` 0.10.4, `genui_a2a` 0.10.1, Flutter 3.47.8) : un `testWidgets` qui lance un agent A2A réel sur `127.0.0.1` et câble `A2uiAgentConnector` → `A2uiTransportAdapter(onSend: connectAndSend)` → `Conversation` + `SurfaceController` rend la `Surface`, et le tap sur un `ElevatedButton` repart vers l'agent (`UiInteractionPart`) puis affiche la réponse. Aucune glue supplémentaire n'est nécessaire côté `genui` ni `genui_a2a`.

Pièges propres au harnais (en application réelle, rien de cela ne s'applique) :
1. **HTTP bloqué** : le binding de test installe un `HttpOverrides` qui répond 400 sans erreur visible (aucune surface, aucun message). Remède : `HttpOverrides.global = null;` dans `setUp` (dans `main()` il est écrasé par le binding).
2. **Zone FakeAsync** : créer le connecteur dans `tester.runAsync(...)`, sinon ses continuations restent dans la zone fake et n'avancent qu'avec `pump`.
3. **Le tap** : l'abonnement de `Conversation` s'exécute dans la zone fake. Boucler en alternant `await tester.runAsync(() => Future.delayed(50 ms))` et `await tester.pump()` jusqu'à voir le texte attendu.
4. **Timer de 15 s** armé par `genui_a2a` dans la zone fake : finir le test par `await tester.pump(const Duration(seconds: 20))`, sinon « A Timer is still pending ».
5. La police `Ahem` de `flutter test` rend les textes en blocs : une capture PNG de test n'est pas lisible ; l'assertion se fait par `find.text`.

Lancer l'agent : compiler son binaire, le démarrer sur un port libre, le tuer par `kill <pid>` à la fin (jamais `pkill` par nom).
