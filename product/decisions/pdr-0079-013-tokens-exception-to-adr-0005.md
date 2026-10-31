---
id: pdr-0079-013-tokens-exception-to-adr-0005
title: "PDR-0079 — 013 : tokens en constantes contrôlées par empreinte, exception à adr-0005 pour la démo"
area: decisions
status: validated
updated: 2026-10-31
sources: []
links: [pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0011-adopt-knowledge-adrs, pdr-0001-conference-demo-deliverable, adr-0005-ds-tokens-style-dictionary, p-rm-open-questions]
tags: [pdr, decision, design-system, tokens, adr, 013]
decision_status: acceptée
decided_on: 2026-10-31
decided_by: "Benoît FONTAINE (porteur), conversation, 2026-10-31"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0079 — 013 : tokens en constantes contrôlées par empreinte, exception à adr-0005 pour la démo

> **En bref.** Pour Genesis Canvas, 013 émet les tokens en constantes `SceneTokens` contrôlées par empreinte au lieu de régénérer avec Style Dictionary (Node) à chaque porte. [adr-0005](../../knowledge/decisions/adr-0005-ds-tokens-style-dictionary.md) reste inchangé : c'est une exception propre à ce produit.

Choix recommandé par l'assistant, décidé par le porteur.

## Contexte
[pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md) D4 s'écarte d'adr-0005 (régénération Style Dictionary en CI) ; écart ouvert en Q-86 par la revue du code de 013. Livrable = démo de conférence ([pdr-0001](pdr-0001-conference-demo-deliverable.md)).

## Hypothèses
- ✅ Écart déjà implémenté par 013 (contrôle par hash et parité).

## Options
1. **Exception pour la démo (retenue)** : pdr-0075 D4 confirmée.
2. Amender adr-0005.
3. Revenir à la régénération Style Dictionary à chaque porte.

## Décision
Question posée le 2026-10-31 : « Q-86 : 013 génère les tokens du design system en constantes contrôlées par empreinte, au lieu de les régénérer avec Style Dictionary (Node) à chaque porte comme le prévoit adr-0005. On l'accepte ? » ; réponse du porteur : « Exception pour la démo (Recommandé) ». Donc : pdr-0075 D4 est confirmée pour Genesis Canvas ; adr-0005 est inchangé ; l'exception est mentionnée dans `inherited` de `decisions/index.yaml` (ligne adr-0005) et dans l'historique de [pdr-0011](pdr-0011-adopt-knowledge-adrs.md).

## Raisons
Réponse du porteur citée ci-dessus ; périmètre de démo (pdr-0001).

## Options écartées
Amender adr-0005 et régénérer à chaque porte : non retenus par le porteur.

## Conséquences
- Q-86 tranchée. Aucun changement dans `knowledge/`.
- Une PDR séparée plutôt qu'une ligne d'historique sur pdr-0075 : la décision vient du porteur, alors que pdr-0075 est une délégation pdr-0062.

## Réexaminer si
- Le produit sort du cadre de la démo ou réutilise ces tokens ailleurs ; l'exception est alors à lever.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée sur la parole du porteur citée ci-dessus (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
