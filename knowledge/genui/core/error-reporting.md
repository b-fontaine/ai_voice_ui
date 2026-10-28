---
id: genui-error-reporting
title: Erreurs de validation renvoyées au LLM (auto-correction)
tags: [genui, a2ui, validation, errors]
status: verified
updated: 2026-10-26
sources: [https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md, https://github.com/flutter/genui/blob/main/packages/genui/lib/src/engine/surface_controller.dart]
links: [genui-user-actions, genui-a2ui-client-messages, genui-prompt-builder, proj-avw-genui-bridge, ux-genui-errors-validation]
---
# genui renvoie les erreurs au LLM pour qu'il se corrige (boucle prompt, génération, validation)

A2UI décrit une boucle en trois temps : prompt, génération, validation. Quand un message ne respecte pas le schéma du catalogue, le client renvoie un `error` standard, et le LLM corrige au tour suivant.

```json
{"version": "v0.9", "error": {"code": "VALIDATION_FAILED", "surfaceId": "main",
  "path": "/components/0/text", "message": "Expected stringOrPath, got integer"}}
```

Dans genui 0.10.x :
- `SurfaceController.reportError` (appelé aussi par `itemContext.reportError` et `SurfaceContext.reportError`) émet un `ChatMessage` qui contient cet `error` sur `onSubmit`.
- `Conversation` le renvoie donc **automatiquement** au LLM, comme une action.
- Une exception levée dans un `widgetBuilder` affiche un `FallbackWidget` et appelle `reportError`. L'erreur part donc aussi au LLM.
- Codes : `VALIDATION_FAILED` (`A2uiValidationException`), `FUNCTION_EXECUTION_FAILED` (`A2uiFunctionException`), sinon `INTERNAL_ERROR`.

⚠️ Pièges
- Risque de boucle : LLM invalide, puis erreur, puis LLM invalide. Plafonner le nombre de tours de correction dans `onSend` (le projet existant limitait à 20 cycles, cf. proj-avw-genui-bridge). Recommandation : 2 ou 3 au plus (opinion).
- Pour un agent vocal, ne pas faire lire ces erreurs à l'utilisateur : les filtrer avant tout retour au canal voix (opinion).
