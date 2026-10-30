---
id: ma-openai-small-model-structured-latency
title: Latence mesurée d'un petit modèle texte en sortie structurée (2026-10-30)
tags: [openai, responses-api, structured-outputs, latence, mesure, reasoning, gpt-6]
status: sourced
updated: 2026-10-30
sources: [mesure interne du 2026-10-30, banc de 25 appels par modèle, passerelle HTTP locale vers l'API Responses]
links: [ma-openai-responses-structured-request, ma-openai-responses-structured-response]
---
# Petit modèle texte, sortie structurée : ce que coûte un appel en temps

**Fait mesuré** (source secondaire : mesure interne, pas une doc officielle ; à refaire si le modèle ou la charge change). Requête Responses à schéma JSON strict : instructions + exemples ≈ 940 jetons en entrée, plan JSON de 60 à 80 jetons en sortie, un appel à la fois, 5 demandes types × 5 répétitions, mesure autour de l'appel HTTP complet (non streaming) :

| Modèle | Plans valides | p50 | p90 | Remarque |
|---|---|---|---|---|
| `gpt-6-luna` (effort par défaut) | 25 / 25 | 1,79 s | 2,69 s | le plus régulier |
| `gpt-6.1-terra` (effort par défaut) | 24 / 25 | 1,97 s | 3,06 s | un appel au-delà du délai de 4 s |

**Effort de raisonnement.** Sur `gpt-6-luna`, `reasoning.effort = minimal` est refusé par l'API (HTTP 400, non facturé) ; `low` et `none` sont acceptés mais ne réduisent pas la latence (p50 2,1 à 2,3 s sur 10 appels). Les valeurs admises dépendent du modèle : à tester avant de les fixer en configuration.

**Conséquence de conception.** Même pour 70 jetons de sortie, un appel de modèle ne tient pas dans un budget de 1,5 s : tout affichage qui doit apparaître avant ce délai ne peut pas attendre la réponse du modèle (émettre d'abord un squelette déterministe, puis les données).

⚠️ Pièges
- Une limite de débit en « jeton par fenêtre » (un jeton se recharge toutes les N secondes) bride un banc de mesure : vérifier la sémantique avant de conclure à une limite du fournisseur.
- Les erreurs 400 de validation ne coûtent rien mais masquent la mesure : classer chaque appel (valide, repli, motif) plutôt que moyenner les latences.
