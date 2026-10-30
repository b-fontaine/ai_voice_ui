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

> **En bref.** La fiche fixe le résultat de l'acte 3 (clic sur « Bloquer la release » → Livraison s'allume → l'IA confirme à la voix → statut « Bloquée »). Elle est muette sur le mécanisme ; la boucle tranche huit détails sous la règle permanente pdr-0062 et les signale au porteur, qui peut les contester. Aucun ne touche le périmètre, la mise en scène des actes, le budget ni les fournisseurs.

Part de l'assistant : décision prise sur délégation (pdr-0062), contestable par le porteur.

## Contexte
009 (J5) réalise FR-08 (S-03, RG-18, RG-28, RG-30). Déjà décidé : pas de confirmation hors GenUI ([pdr-0059](pdr-0059-acts-2-3-and-replay-simplifications.md)), « Valider la release » symétrique ([pdr-0016](pdr-0016-validate-release-action.md)), Barre d'actions à la fin de l'acte 2 ([pdr-0061](pdr-0061-action-bar-appears-end-of-act-2.md)), résultat d'outil réel ([ma-real-tool-results]).

## Hypothèses
- ✅ Fiche muette sur le transport du clic, la forme de la Barre d'actions et la manière dont la voix confirme ; ni périmètre, ni mise en scène, ni budget, ni fournisseur.
- ⚠️ Hypothèse non confirmée (Q-75) : GPT-Live en mode `client` dit effectivement un `commentary.append` à `delegation_id` nul. Le SDK le documente, aucun essai ne l'a observé ; un seul essai réel est prévu à la vérification de 009 (D5).

## Décision
- **D1 — Transport du clic : `POST /canvas/actions`** (HTTP, même jeu de gardes que `POST /canvas/reset` : `Host`, `Origin` absent, `application/json`, corps ≤ 1 Kio, aucun CORS). Corps `{"action": "<nom>", "surface": "<id>"}` : **aucune donnée du client n'est relayée à l'agent**. Réponses : 202 acceptée, 400 corps illisible, 403 `Origin`, 413, 415, 422 action inconnue ou surface qui ne la porte pas, 409 `{error: "busy"}` (délégation ou action en cours) ou `{error: "no_session"}` (aucune session voix ouverte). Une écoute WSS montante n'est pas ajoutée : le hub est en diffusion seule et la route donne un accusé synchrone.
- **D2 — Barre d'actions = cinquième surface `actions`** (`ActionBar`), créée par l'agent Livraison dans la tâche de l'acte 2 qui met la checklist en vue plateforme (donc avec la recommandation **NO-GO Android**, pdr-0061), seulement si elle manque. Les quatre surfaces de l'acte 1 ne sont toujours ni recréées ni supprimées ; les assertions « aucun `createSurface` » de 008 se restreignent à ces quatre surfaces. L'étagère passe à « 5 / 6 utilisés ». Donnée : `{title, actions: [{id, label, tone}]}` avec `id` ∈ {`block_release`, `validate_release`}.
- **D3 — Résultat par sous-chemin** : l'agent Livraison répond par `updateDataModel` sur `/checklist/decisionStatus` (libellés du jeu de données : « Bloquée », « Validée »). Critères, recommandation et comparaison restent affichés tels quels (la décision humaine prime sur la recommandation). C'est une exception à la règle « chemin entier » de [pdr-0064](pdr-0064-008-act2-transform-details-assistant-decided.md) D1, justifiée par l'agent sans état (il ne sait pas quelle vue est affichée). Repli si la liaison de l'app ne se met pas à jour sur un sous-chemin : voir le plan de 009.
- **D4 — Routage par tags de carte** : l'action est confiée à l'agent dont la carte annonce le tag `action:<nom>` (Livraison : `action:block_release`, `action:validate_release`), jamais à un nom d'agent codé en dur (RG-29). Le nom d'action est validé (`^[a-z][a-z_]{0,39}$`) et doit figurer dans les tags de cartes lues ; l'agent reçoit l'action dans les métadonnées du message A2A (`genesis/action`), pas dans un texte libre.
- **D5 — Voix hors délégation** : la confirmation n'est dite qu'**après** le résultat réel de l'agent, tâche `completed` et messages valides (même politique qu'aux actes 1 et 2). Le port de la voix reçoit une annonce ; la politique essaie dans l'ordre : (1) `session.commentary.append` avec `delegation_id` nul (le SDK openai-go v3.90.0 le documente « nullable, nul pour le contexte général de la session »), (2) **seulement sur erreur d'acquittement**, le même commentaire rattaché à la dernière délégation de la session si elle existe, (3) `session.instructions.append` avec un texte propre à l'orchestrateur, jamais le résumé de l'agent. **Jamais de second envoi sur silence** (la voix pourrait dire deux fois la confirmation) : l'attente d'un transcript sortant ne sert qu'à observer (Q-75). Si rien ne fait parler la voix, rien n'est inventé : l'interface a déjà changé et le fait est journalisé. Pas de faux transcript.
- **D6 — Sémantique du clic** : pendant une action, les deux boutons sont inactifs (état `busy` côté app, 409 `busy` côté backend, réessai borné comme la remise à vide) ; un nouveau clic après le résultat est permis (« Bloquer » puis « Valider » donne « Validée ») ; échec de l'agent : checklist inchangée, phrase d'échec honnête dite, rail en `failed`.

- **D7 — Mise en page** : la Barre d'actions est un **bandeau sous la grille 2×2**, hors de la grille ; les quatre surfaces de l'acte 1 gardent position et état de rendu (S-02 de la fiche, « les surfaces existantes restent à leur place », intact). Détail d'interface sur lequel la fiche est muette (pdr-0015 : mise en page tenue par l'app).
- **D8 — Budget des zones de l'écran (1920×1080)** : pour loger le bandeau sans réduire les cellules de la grille sous 248 px (à 220 px, l'acte 2 débordait), la barre supérieure passe de 160 à 128 px, la marge verticale de 18 à 8 px et le canevas de 520 à 572 px (grille 2×250 + bandeau de 72 px) ; le rail garde ses 200 px. Le bandeau est réservé dès la première surface, donc **une bande vide de 72 px reste en bas du canevas pendant les actes 1 et 2** (c'est le prix d'une grille qui ne bouge pas, S-02). Détail d'interface sur lequel la fiche est muette ; à valider visuellement à la capture.
## Raisons
- D1 : réutilise une route et des gardes déjà testées (007) ; un clic n'est pas un flux ; l'accusé évite un clic perdu en silence.
- D2 : pdr-0061 veut la barre visible à la fin de l'acte 2 sans ajouter de surface en acte 3 ; le catalogue fermé (pdr-0014) la prévoit déjà.
- D3 : le jeu de données fixe les libellés ; ne rien recalculer ni dupliquer côté agent.
- D4 : l'orchestrateur ne fait confiance qu'à ce que ses cartes annoncent ([genui-a2ui-security] : un clic est un événement typé, jamais une commande libre).
- D8 : la hauteur utile de la grille est la contrainte ; le rail ne peut pas céder de place (cas « aucun agent retenu », 5 lignes).
- D7 : une grille 3×2 déplacerait les quatre surfaces et recréerait leur état de rendu, ce qui contredit S-02 ; seul le porteur pourrait l'assouplir.
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
| 2026-10-30 | Revue du code (architect-reviewer, À REFACTORISER) : D8 ajouté (budget des zones modifié par T17 sans trace décisionnelle). Détail d'interface sous pdr-0062 ; la bande vide des actes 1 et 2 est signalée au porteur. | Assistant (délégation du porteur, pdr-0062) |
| 2026-10-30 | Revue du plan (architect-reviewer, À AMENDER) : D5 amendé (ordre des stratégies, pas de renvoi sur silence, consigne propre à l'orchestrateur : contrainte par le SDK et par la règle « résultat réel »), D7 ajouté (bandeau hors grille). Aucune décision du porteur n'est touchée. | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
