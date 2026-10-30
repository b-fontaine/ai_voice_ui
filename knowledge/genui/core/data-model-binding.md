---
id: genui-data-model
title: DataModel et data binding (chemins JSON Pointer)
tags: [genui, a2ui, data-binding, state]
status: verified
updated: 2026-10-30
sources: [https://docs.flutter.dev/ai/genui/get-started, https://github.com/google/A2UI/blob/main/specification/v0_9_1/docs/a2ui_protocol.md, https://a2ui.org/concepts/data-binding/, https://github.com/flutter/genui/blob/main/docs/usage/migration/migration_0.9.1_to_0.10.0.md]
links: [genui-a2ui-messages, genui-user-actions, genui-custom-catalog-item]
---
# Chaque surface a un DataModel observable ; les propriétés s'y lient par `{"path": ...}`

Une propriété de composant A2UI est soit un littéral JSON, soit un objet `{"path": "/user/name"}` (JSON Pointer) lié au `DataModel` de la surface. Seuls les widgets qui dépendent d'un chemin modifié sont reconstruits.

```json
{"id": "name", "component": "TextField", "label": "Nom", "value": {"path": "/contact/firstName"}}
```

- **Écriture côté agent :** `updateDataModel {surfaceId, path, value}` remplace la valeur au chemin donné. Sans `path`, ou avec `/`, tout le modèle est remplacé. Un `value` absent ou `null` supprime la clé.
- **Écriture côté utilisateur :** les inputs (`TextField`, `CheckBox`, `Slider`, `ChoicePicker`…) écrivent directement dans le modèle (binding bidirectionnel), sans aller-retour avec le LLM.
- **Lecture en Dart :** `controller.contextFor(id).dataModel`. Dans un `CatalogItem`, utiliser `itemContext.dataContext` (`subscribe<T>(DataPath)`, `getValue<T>`, `update`) ou les widgets `BoundString`, `BoundBool`, `BoundNumber`, `BoundList` et `BoundObject`.
- **Portée :** dans un template de liste, les chemins relatifs se résolvent par rapport à l'élément courant.
- **Fonctions :** `formatString`, `formatDate`, `required`, `email`… s'évaluent côté client (`{"call": ..., "args": ...}`).

⚠️ Pièges
- Depuis 0.10, les écritures sont plus strictes : écrire à travers une valeur intermédiaire qui n'est ni map ni liste lève une exception.
- Le modèle ne remonte à l'agent que dans le `context` d'une action, ou si `createSurface.sendDataModel: true` (via les métadonnées du transport).
- **Mutation en place (vérifié sur genui 0.10.4) :** un `updateDataModel` seul, sur une surface déjà montée, met à jour les `BoundObject` abonnés au chemin sans reconstruire la surface ni son `State`. Il remplace l'objet entier : un champ facultatif absent de la nouvelle valeur disparaît du rendu (une ligne de comparaison s'efface si la valeur suivante n'en porte pas). Écrire toujours le chemin entier de la surface.
- **Écriture d'un sous-chemin (vérifié sur genui 0.10.4, test de widget)** : un `updateDataModel` seul sur `/objet/champ` met à jour le `BoundObject` abonné à `/objet` sans reconstruire la surface ni son `State` (`DataModel.set` notifie aussi les ancêtres du chemin écrit) ; le reste de l'objet est conservé. Utile pour changer un seul champ sans connaître le reste de l'objet, au prix d'un contrat plus fin : tout sous-chemin accepté doit être déclaré et son type contrôlé.
- En A2UI v1.0 RC, le binding devient `{"@path": ...}`. Voir genui-a2ui-v1-rc.
