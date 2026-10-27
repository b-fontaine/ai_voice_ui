---
id: genui-a2ui-messages
title: A2UI v0.9 — les 4 messages agent → client
tags: [a2ui, protocol, messages, json]
status: verified
updated: 2026-10-26
sources: [https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md, https://a2ui.org/specification/v0.9-a2ui/]
links: [genui-a2ui-overview, genui-data-model, genui-multiple-surfaces, genui-catalog-ids, genui-a2ui-client-messages]
---
# Chaque message contient `version` et exactement une clé : createSurface, updateComponents, updateDataModel ou deleteSurface

```jsonl
{"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json","sendDataModel":true}}
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
  {"id":"root","component":"Column","children":["title","name"]},
  {"id":"title","component":"Text","text":"# Profil","variant":"h2"},
  {"id":"name","component":"TextField","label":"Nom","value":{"path":"/user/name"}}]}}
{"version":"v0.9","updateDataModel":{"surfaceId":"main","path":"/user/name","value":"Alice"}}
{"version":"v0.9","deleteSurface":{"surfaceId":"main"}}
```

- **createSurface** `{surfaceId, catalogId, theme?, sendDataModel?}` : `surfaceId` et `catalogId` sont figés. Un composant doit avoir l'id `root`.
- **updateComponents** `{surfaceId, components[]}` : liste plate. Les enfants sont référencés par id (`child`, `children`) et peuvent arriver plus tard (rendu progressif).
- **updateDataModel** `{surfaceId, path?, value?}` : remplace la valeur au chemin JSON Pointer. Sans `value`, la clé est supprimée.
- **deleteSurface** `{surfaceId}`.
- Format de composant v0.9 : discriminant plat `"component": "Text"` (et non plus `{"Text": {...}}` comme en v0.8).
- MIME standard (v0.9.1) : `application/a2ui+json`.

⚠️ Pièges
- Le transport doit garantir l'**ordre** des messages : un update avant le create corrompt l'état. genui met ces updates en tampon pendant `pendingUpdateTimeout`.
- `createSurface` sur un id actif est une erreur : il faut d'abord `deleteSurface`.
- Les exemples de la spec v0.9.1 portent `"version": "v0.9.1"`, que genui 0.10.x refuse (`a2ui_core` exige `"v0.9"`).
- La doc Flutter « components » cite encore les noms v0.8 (`surfaceUpdate`, `dataModelUpdate`). Seuls ceux ci-dessus sont valides en v0.9.
