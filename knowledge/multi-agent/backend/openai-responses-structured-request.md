---
id: ma-openai-responses-structured-request
title: API Responses OpenAI, sortie structurée — requête (net/http, 2026-10-30)
tags: [openai, responses-api, structured-outputs, json-schema, backend, go, reasoning]
status: verified
updated: 2026-10-30
sources: [https://developers.openai.com/api/reference/resources/responses/methods/create, https://developers.openai.com/api/docs/guides/structured-outputs, https://developers.openai.com/api/docs/guides/reasoning, https://developers.openai.com/api/reference/overview]
links: [ma-openai-responses-structured-response, ma-backend-sdk-go, rt-ephemeral-keys]
---
# Responses API : générer du JSON contraint par un schéma (vérifié le 2026-10-30)

**Endpoint :** `POST https://api.openai.com/v1/responses`. En-têtes : `Authorization: Bearer <clé>`, `Content-Type: application/json` (ce dernier n'est pas nommé par la page de référence, usage standard). Optionnels : `OpenAI-Organization`, `OpenAI-Project`, `X-Client-Request-Id` (ASCII, 512 car. max) ; la réponse porte `x-request-id` et `x-ratelimit-*`. La clé reste côté backend ([[rt-ephemeral-keys]]).

**Corps minimal (texte seul, sans outil) :**
```json
{"model": "<id>", "instructions": "…", "input": "…",
 "max_output_tokens": 2000, "store": false,
 "text": {"format": {"type": "json_schema", "name": "my_schema",
          "strict": true, "schema": {"type": "object", "properties": {…},
          "required": […], "additionalProperties": false}}}}
```
- `instructions` : message système, string ; `input` : string ou tableau d'items (`{"role","content"}`).
- `text.format` : `name` obligatoire (lettres, chiffres, `_`, `-`, 64 car. max), `schema` obligatoire, `strict` vaut **false par défaut** : à mettre à `true`. `description` optionnel.
- `max_output_tokens` : minimum 16 ; borne **raisonnement + sortie visible**.
- `store` : défaut `true` (conservation 30 jours minimum) ; mettre `false` pour ne rien conserver.
- Sans `tools`, aucun appel d'outil. Anciens modes : `{"type":"json_object"}` (JSON valide sans schéma, déconseillé).

**Mode strict (types et règles) :**
- Racine = objet, **pas de `anyOf` à la racine**. Chaque objet : `additionalProperties: false`.
- **Tous** les champs dans `required` ; un champ facultatif = union avec `null` (`"type": ["string","null"]`).
- Types : string, number, integer, boolean, object, array, enum, `anyOf`. `$defs`/`$ref` et récursion supportés.
- Contraintes : string `pattern` et `format` (date-time, time, date, duration, email, hostname, ipv4, ipv6, uuid) ; nombres `minimum`/`maximum`/`exclusive*`/`multipleOf` ; tableaux `minItems`/`maxItems`.
- Interdits : `allOf`, `not`, `dependentRequired`, `dependentSchemas`, `if/then/else`. Un schéma non supporté avec `strict: true` renvoie une erreur.
- Limites : 5 000 propriétés au total, 10 niveaux d'imbrication, 120 000 car. cumulés (noms, enum, const), 1 000 valeurs d'enum. Les clés sortent dans l'ordre du schéma.
- Première requête avec un schéma neuf : latence supplémentaire ; les suivantes non.

**Modèle à raisonnement et `max_output_tokens` :** les jetons de raisonnement comptent dans la borne ; si elle est atteinte avant le JSON, la réponse est `incomplete` sans texte visible, et l'entrée plus le raisonnement sont facturés. La doc conseille de réserver au moins 25 000 jetons pour raisonnement et sortie au départ. `reasoning.effort` : `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max` (défaut `medium`) ; les valeurs admises dépendent du modèle (GPT-6 Astra refuse `none` en HTTP 400 ; GPT-6.1 Sol refuse `none` et `minimal`). ⚠️ non vérifié : valeurs admises pour Luna et Terra.

**Base URL différente :** avec `net/http`, c'est la constante de l'URL elle-même (aucune variable imposée). Pour les SDK, `OPENAI_BASE_URL` (Java, Python) ou l'option `base_url` ; défaut `https://api.openai.com/v1`. ⚠️ non vérifié dans la doc officielle de `openai-go`. Un faux serveur de test se branche en pointant la base vers `httptest.Server`.

**Modèles rapides listés par la page Models (2026-10-30, sans date de sortie) :** `gpt-6-astra` (le plus capable), `gpt-6.1-sol` (proche d'Astra, moins cher), `gpt-6.1-terra` (« rapide et efficace »), `gpt-6-luna` (« le plus efficace, tâches ciblées à fort volume »). Aucun « mini » ou « nano » n'est listé pour le texte général ; la page ne donne pas de chiffres de latence.

⚠️ Pièges : oublier `strict: true` (défaut false) ; `additionalProperties` manquant sur un objet imbriqué ; budget `max_output_tokens` trop bas avec un modèle à raisonnement.
