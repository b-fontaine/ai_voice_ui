---
id: pdr-0065-009-act3-interact-details-assistant-decided
title: "PDR-0065 — Acte 3 (J5) : route d'action HTTP, Barre d'actions en cinquième surface, résultat par sous-chemin, voix hors délégation"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/009-j5-act3-interact/spec.md, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p10]
links: [p-rm-open-questions, p-fn-catalog, p-fn-dataset-acts, p-fn-requirements, p-ar-agents-protocols, p-ar-app-channel-contract, p-ar-security, pdr-0016-validate-release-action, pdr-0059-acts-2-3-and-replay-simplifications, pdr-0061-action-bar-appears-end-of-act-2, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0064-008-act2-transform-details-assistant-decided, ma-real-tool-results, genui-user-actions, genui-data-model, rt-gpt-live-delegation]
tags: [pdr, decision, acte-3, action, fr-08]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0065 — Acte 3 (J5) : détails de l'interaction

> **En bref.** La fiche fixe le résultat de l'acte 3 (clic sur « Bloquer la release » → Livraison s'allume → l'IA confirme à la voix → statut « Bloquée »). Elle est muette sur le mécanisme ; la boucle tranche six détails sous la règle permanente pdr-0062 et les signale au porteur, qui peut les contester. Aucun ne touche le périmètre, la mise en scène des actes, le budget ni les fournisseurs.

Part de l'assistant : décision prise sur délégation (pdr-0062), contestable par le porteur.

## Contexte
009 (J5) réalise FR-08 (S-03, RG-18, RG-28, RG-30). Déjà décidé : pas de confirmation hors GenUI ([pdr-0059](pdr-0059-acts-2-3-and-replay-simplifications.md)), « Valider la release » symétrique ([pdr-0016](pdr-0016-validate-release-action.md)), Barre d'actions à la fin de l'acte 2 ([pdr-0061](pdr-0061-action-bar-appears-end-of-act-2.md)), résultat d'outil réel ([ma-real-tool-results]).

## Hypothèses
- ✅ Fiche muette sur le transport du clic, la forme de la Barre d'actions et la manière dont la voix confirme ; ni périmètre, ni mise en scène, ni budget, ni fournisseur.
- ⚠️ Hypothèse non confirmée (Q-75) : GPT-Live en mode `client` accepte de dire un texte **hors de toute délégation** (le clic n'est pas une demande parlée). Aucune note ne le vérifie ; un seul essai réel est prévu à la vérification de 009, qui essaie les stratégies dans l'ordre (D5).

## Décision
- **D1 — Transport du clic : `POST /canvas/actions`** (HTTP, même jeu de gardes que `POST /canvas/reset` : `Host`, `Origin` absent, `application/json`, corps ≤ 1 Kio, aucun CORS). Corps `{"action": "<nom>", "surface": "<id>"}` : **aucune donnée du client n'est relayée à l'agent**. Réponses : 202 acceptée, 400 corps illisible, 403 `Origin`, 413, 415, 422 action inconnue ou surface qui ne la porte pas, 409 `{error: "busy"}` (délégation ou action en cours) ou `{error: "no_session"}` (aucune session voix ouverte). Une écoute WSS montante n'est pas ajoutée : le hub est en diffusion seule et la route donne un accusé synchrone.
- **D2 — Barre d'actions = cinquième surface `actions`** (`ActionBar`), créée par l'agent Livraison dans la tâche de l'acte 2 qui met la checklist en vue plateforme (donc avec la recommandation **NO-GO Android**, pdr-0061), seulement si elle manque. Les quatre surfaces de l'acte 1 ne sont toujours ni recréées ni supprimées ; les assertions « aucun `createSurface` » de 008 se restreignent à ces quatre surfaces. L'étagère passe à « 5 / 6 utilisés ». Donnée : `{title, actions: [{id, label, tone}]}` avec `id` ∈ {`block_release`, `validate_release`}.
- **D3 — Résultat par sous-chemin** : l'agent Livraison répond par `updateDataModel` sur `/checklist/decisionStatus` (libellés du jeu de données : « Bloquée », « Validée »). Critères, recommandation et comparaison restent affichés tels quels (la décision humaine prime sur la recommandation). C'est une exception à la règle « chemin entier » de [pdr-0064](pdr-0064-008-act2-transform-details-assistant-decided.md) D1, justifiée par l'agent sans état (il ne sait pas quelle vue est affichée). Repli si la liaison de l'app ne se met pas à jour sur un sous-chemin : voir le plan de 009.
- **D4 — Routage par tags de carte** : l'action est confiée à l'agent dont la carte annonce le tag `action:<nom>` (Livraison : `action:block_release`, `action:validate_release`), jamais à un nom d'agent codé en dur (RG-29). Le nom d'action est validé (`^[a-z][a-z_]{0,39}$`) et doit figurer dans les tags de cartes lues ; l'agent reçoit l'action dans les métadonnées du message A2A (`genesis/action`), pas dans un texte libre.
- **D5 — Voix hors délégation** : la confirmation n'est dite qu'**après** le résultat réel de l'agent, tâche `completed` et messages valides (même politique qu'aux actes 1 et 2). Le port de la voix reçoit `Announce(texte)` ; l'adaptateur essaie dans l'ordre, jusqu'à ce que la voix parle (transcript sortant dans un délai borné) : `session.commentary.append` rattaché à la dernière délégation de la session, puis `session.instructions.append`. Si aucune stratégie ne fait parler la voix, rien n'est inventé : l'interface a déjà changé (rail, statut) et l'échec est journalisé. Pas de faux transcript.
- **D6 — Sémantique du clic** : pendant une action, les deux boutons sont inactifs (état `busy` côté app, 409 `busy` côté backend, réessai borné comme la remise à vide) ; un nouveau clic après le résultat est permis (« Bloquer » puis « Valider » donne « Validée ») ; échec de l'agent : checklist inchangée, phrase d'échec honnête dite, rail en `failed`.

## Raisons
- D1 : réutilise une route et des gardes déjà testées (007) ; un clic n'est pas un flux ; l'accusé évite un clic perdu en silence.
- D2 : pdr-0061 veut la barre visible à la fin de l'acte 2 sans ajouter de surface en acte 3 ; le catalogue fermé (pdr-0014) la prévoit déjà.
- D3 : le jeu de données fixe les libellés ; ne rien recalculer ni dupliquer côté agent.
- D4 : l'orchestrateur ne fait confiance qu'à ce que ses cartes annoncent ([genui-a2ui-security] : un clic est un événement typé, jamais une commande libre).
- D5 : [ma-real-tool-results] : jamais de confirmation avant le résultat ; [rt-gpt-live-delegation] ne documente que `commentary.append` par délégation.

## Options écartées
- Écoute WSS montante de l'app : second protocole, pas d'accusé, plafond de lecture à écrire.
- Barre d'actions dans la surface de la checklist : le composant `ReleaseChecklist` n'a pas de bouton (pdr-0014 : six composants distincts).
- Nouvelle écriture du chemin entier de la checklist : exige que l'agent connaisse la vue affichée (état côté agent, contraire à 008).
- Simuler la voix par un transcript fabriqué : contraire à pdr-0023/NFR-08 (rien de faux à l'écran).

## Conséquences
- Contrat `genesis/v1` : `ActionBar` passe de `catalogComponents` à `components` (5 composants avec schéma) ; fixtures `act2-actions` et `act3-*` ; [p-fn-catalog](../functional/catalog.md), [p-fn-dataset-acts](../functional/dataset-acts.md), [p-ar-agents-protocols](../architecture/agents-protocols.md), [p-ar-app-channel-contract](../architecture/app-channel-contract.md), [p-ar-security](../architecture/security.md) : complétés à la clôture de 009.
- `specs/progress.md` : signalé au porteur (D2 et D5 en particulier).

## Réexaminer si
- l'essai réel montre que la voix ne dit rien hors délégation (Q-75) ;
- le porteur conteste l'un des détails, ou si la répétition montre que la barre apparaît trop tôt ou trop discrètement.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée sous la règle permanente pdr-0062 (fiche muette, détails d'interface et de mécanisme). | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
