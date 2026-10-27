---
id: genui-test-surface-controller
title: Tester le rendu bout en bout avec SurfaceController (sans LLM)
tags: [genui, testing, widget-test, a2ui, transport]
status: verified
updated: 2026-10-26
sources: [https://github.com/flutter/genui/blob/main/packages/genui/test/genui_surface_test.dart, https://github.com/flutter/genui/blob/main/docs/usage/migration/migration_0.9.1_to_0.10.0.md]
links: [genui-test-catalog-items, genui-a2ui-messages, genui-custom-llm-adapter, genui-user-actions, test-mock-boundaries-only]
---
# On injecte des messages A2UI scriptés dans `SurfaceController`, puis on pompe un `Surface`

```dart
// genui 0.10.4 : messages de package:a2ui_core (0.10.6+ : package:genui/a2ui_core.dart)
final controller = SurfaceController(catalogs: [Catalog([...], catalogId: 'test')]);
controller.handleMessage(CreateSurfaceMessage(surfaceId: 's', catalogId: 'test'));
controller.handleMessage(UpdateComponentsMessage(surfaceId: 's', components: [
  {'id': 'root', 'component': 'Button', 'child': 't',
   'action': {'event': {'name': 'ok'}}},
  {'id': 't', 'component': 'Text', 'text': 'Valider'},
]));
await tester.pumpWidget(MaterialApp(home: Surface(surfaceContext: controller.contextFor('s'))));
expect(find.text('Valider'), findsOneWidget);

final submitted = controller.onSubmit.first;   // action renvoyée à l'agent
await tester.tap(find.byType(ElevatedButton));
expect((await submitted).parts.single.isUiInteractionPart, isTrue);
```

Niveaux de test recommandés (opinion) :
1. **Unitaire de catalogue :** voir genui-test-catalog-items.
2. **Rendu de surface :** fixtures JSONL réelles (enregistrées depuis le LLM) rejouées via `A2uiMessage.fromJson`, ou via `A2uiTransportAdapter.addChunk` pour tester aussi le parseur.
3. **Transport :** `Transport` factice qui renvoie des chunks scriptés, pour tester `Conversation`, les événements et le BLoC hôte sans réseau.
4. **Évaluation LLM** (hors CI) : vérifier que le prompt produit du JSON valide pour un panel d'intentions.

⚠️ Pièges
- `tearDown(controller.dispose)`.
- Le snippet est adapté de `genui_surface_test.dart`, qui passe par des helpers privés (`test_infra/message_builders.dart`). Les constructeurs `a2ui_core` (`CreateSurfaceMessage`, `UpdateComponentsMessage`…) ont un `version` optionnel, `'v0.9'` par défaut (a2ui_core 0.1.0 et copie 0.10.6).
