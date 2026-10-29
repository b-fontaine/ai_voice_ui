# SP-03 — Notes S3 (client Flutter) et S4 (aller-retour d'une action)

Date : 2026-10-29. Verdict : **S3 et S4 réussis de bout en bout, contre l'agent Go réel** (processus lancé par le test, HTTP/SSE réel sur 127.0.0.1).

## Versions résolues
Flutter 3.47.8 (Dart 3.13.7), `genui` 0.10.4, `genui_a2a` 0.10.1, `a2ui_core` 0.1.1, `http` 1.6.0, `sse_channel` 0.2.2. Agent : celui de S2 (`a2a-go/v2` v2.7.0, Go 1.27.3), non modifié.

## Projet
`spikes/sp03-a2a/client/` (`pubspec.yaml` avec versions exactes, sans `resolution: workspace`). **Aucun contournement nécessaire** : `flutter pub get` fonctionne tel quel, le pubspec workspace racine ne le revendique pas. Seul avertissement (bénin) : « genui_a2a has `uses-material-design: true` but the primary pubspec contains false ».

Test : `test/a2a_roundtrip_test.dart` (un `testWidgets`). Commande :

```
(cd spikes/sp03-a2a/agent && go build -o $SP/sp03agent .)
cd spikes/sp03-a2a/client
flutter test --dart-define=AGENT_BIN=$SP/sp03agent --dart-define=PNG_DIR=$SP   # PNG_DIR facultatif
```
Sortie finale : `Shell: ... agent A2A (compat v0.3) sur http://127.0.0.1:45673` / `action reçue : validate` / `arrêt propre` / `+1: All tests passed!` ; `dart analyze test` : No issues ; `pgrep sp03agent` : aucun processus restant (`agent.kill()` = SIGTERM sur le seul PID lancé, port libre pris par `ServerSocket.bind(…, 0)`).

## Câblage testé (celui de [genui-a2a-connector])
`A2uiAgentConnector(url)` -> `connector.stream.listen(transport.addMessage)` ; `A2uiTransportAdapter(onSend: connectAndSend(msg, clientCapabilities: controller.clientCapabilities))` ; `Conversation(controller, transport)` ; `Surface(surfaceContext: controller.contextFor(id))` pour chaque `conversation.state.value.surfaces`. Catalogue : `BasicCatalogItems.asCatalog()`.

## S3 — réel et vérifié
- `conversation.sendRequest(ChatMessage.user('bonjour'))` -> `message/stream` réel -> `CreateSurface`, `UpdateComponents`, `UpdateDataModel` parsés par `a2ui_core` 0.9 (confirme les questions ouvertes de S1 : `Button.child` + `action.event`, `Text.text` lié par `{path}` sont acceptés) -> `SurfaceAdded`, `ComponentsUpdated`.
- Assertions : `find.byType(Surface)` = 1 ; `find.text('Sessions sans crash')` et `find.text('99,57 %')` = 1 ; « validé » absent ; `errorStream` vide ; un seul envoi à l'agent.

## S4 — réel et vérifié
- `tester.tap(find.byType(ElevatedButton))` (bouton « Valider ») -> `controller.onSubmit` -> `Conversation.sendRequest` -> `onSend` -> `connectAndSend` avec un `ChatMessage` dont la part est une `UiInteractionPart` contenant `"validate"` (assertions `isUiInteractionPart`, `interaction contains "validate"`). L'agent journalise `action reçue : validate`, répond `updateDataModel /status = "validé"` ; `find.text('validé')` = 1 dans la surface. `sentToAgent` = 2 appels exactement.
- **Aucune glue supplémentaire côté `genui` ni `genui_a2a`** : `Conversation` + `A2uiTransportAdapter(onSend: connectAndSend)` suffisent. Le seul impératif (déjà noté en S1) : ne pas utiliser `sendEvent`. Sans `Conversation` (câblage manuel), écouter `controller.onSubmit` soi-même.

## Pièges rencontrés (tous côté harnais de test, pas côté produit)
1. **`testWidgets` bloque le HTTP** : le binding installe un `HttpOverrides` qui répond 400 (avertissement « all HTTP requests will return status code 400 »). Symptôme : aucune erreur, aucune surface (le connecteur n'a rien émis). Remède : `HttpOverrides.global = null;` **dans `setUp`** (pas dans `main()` : le binding l'écrase à son initialisation, qui a lieu après le corps de `main`).
2. **Zone FakeAsync** : un `A2uiAgentConnector` créé dans le corps de `testWidgets` garde ses continuations dans la zone fake et ne progresse qu'avec `pump`. Remède : créer le connecteur dans `tester.runAsync(...)`, et attendre les E/S réelles dans `runAsync`.
3. **Le clic** : l'abonnement `onSubmit` de `Conversation` (créée dans la zone fake) lance `connectAndSend` dans la zone fake. Remède : boucle alternant `await tester.runAsync(() => Future.delayed(50 ms))` et `await tester.pump()` jusqu'à voir « validé ». Sans cela, la requête part avec ~2 s de retard (observé : l'agent ne la reçoit qu'à la fin du test) et la surface n'est pas mise à jour dans le test.
4. `genui_a2a` arme un `Timer` de 15 s dans la zone fake : fin de test par `await tester.pump(const Duration(seconds: 20))`, sinon « A Timer is still pending even after the widget tree was disposed ».
Ces 4 points sont propres aux tests ; en application réelle (zone racine) rien de tout cela ne s'applique.

## Réel / non réel
Réel : agent Go compilé, processus, TCP, JSON-RPC/SSE, `A2uiAgentConnector`, parseur `a2ui_core`, `SurfaceController`, `Surface`, `Conversation`, tap simulé. Non réel : le **tap** est simulé par `WidgetTester` (pas de vrai pointeur) ; le moteur de rendu est celui de `flutter test` (police Ahem, donc la capture montre des blocs et non du texte lisible).

## Capture
Deux PNG via `RepaintBoundary.toImage` (avec `--dart-define=PNG_DIR=`) : avant clic (3 lignes + bouton) et après clic (4 lignes dont « validé »), sous le scratchpad : `.../scratchpad/sp03_avant.png` et `.../scratchpad/sp03_apres.png` (hors dépôt ; `client/*.png` est ignoré par git).
