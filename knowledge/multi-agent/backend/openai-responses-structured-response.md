---
id: ma-openai-responses-structured-response
title: API Responses OpenAI, sortie structurée — lecture de la réponse (2026-10-30)
tags: [openai, responses-api, structured-outputs, json-schema, backend, go, reasoning]
status: verified
updated: 2026-10-30
sources: [https://developers.openai.com/api/reference/resources/responses/methods/create, https://developers.openai.com/api/docs/guides/structured-outputs, https://developers.openai.com/api/docs/guides/reasoning]
links: [ma-openai-responses-structured-request, ma-backend-sdk-go]
---
# Responses API : lire une réponse JSON structurée (vérifié le 2026-10-30)

**Où lire le JSON :** `output` est un tableau d'items. Chercher l'item `type: "message"` (`role: "assistant"`), puis dans `content[]` l'élément `type: "output_text"` dont le champ `text` est la chaîne JSON à décoder. `output` peut aussi contenir des items `reasoning` (à ignorer) avant le message : ne pas lire `output[0]` à l'aveugle.

**`output_text` n'est pas un champ du JSON brut :** la doc le décrit comme une propriété de commodité des SDK Python et JavaScript. Depuis `net/http`, parcourir `output[].content[]`.

**`status` de la réponse :** `completed`, `failed`, `in_progress`, `cancelled`, `queued` ou `incomplete`. Sans `background`, on attend `completed` ou `incomplete`.
- `incomplete` : `incomplete_details.reason` vaut `max_output_tokens` (borne atteinte, JSON tronqué ou absent) ou `content_filter` (génération arrêtée). Ne jamais décoder le texte d'une réponse `incomplete`.
- Champ `error` (null dans l'exemple de la doc) : ⚠️ non vérifié, sémantique des erreurs HTTP (400 schéma invalide, 401, 429) et forme de leur corps non relues dans la doc.

**Refus :** un item de `content[]` de `type: "refusal"` avec un champ `refusal` (string d'explication) remplace `output_text`. La sortie ne respecte alors pas le schéma ; tester le type avant de décoder.

**`usage` :** `input_tokens`, `output_tokens`, `total_tokens` et `output_tokens_details.reasoning_tokens` (inclus dans `output_tokens`, facturés comme sortie, invisibles via l'API). Exemple de la doc : `output_tokens` 1186 dont 1024 de raisonnement.

**Algorithme de lecture conseillé :**
1. Code HTTP 2xx, sinon lire `error`.
2. `status == "completed"`, sinon traiter `incomplete_details.reason`.
3. Trouver le message, rejeter un `refusal`, décoder `text`.
4. Valider le JSON décodé côté Go (le mode strict garantit la conformité au schéma, pas la sémantique).

Le prompt doit demander du JSON (instructions) ; sans cela, le modèle peut produire du blanc jusqu'à la borne de jetons (cité pour le mode JSON de la doc).

⚠️ Pièges : lire `output[0]` ; supposer `output_text` en REST ; traiter un `incomplete` comme un succès ; compter sur `max_output_tokens` bas avec un modèle à raisonnement ([[ma-openai-responses-structured-request]]).
