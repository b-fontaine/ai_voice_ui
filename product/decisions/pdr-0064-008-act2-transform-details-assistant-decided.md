---
id: pdr-0064-008-act2-transform-details-assistant-decided
title: "PDR-0064 — Acte 2 (J4) : mutation par données seules, comparaison 3.3 dans les composants existants, correction de plateforme sans annulation"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/008-j4-act2-transform/spec.md, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p10]
links: [p-rm-open-questions, p-fn-catalog, p-fn-dataset, p-fn-requirements, p-ar-agents-protocols, pdr-0024-act2-android-only, pdr-0058-backend-canvas-registry-survives-voice-sessions, pdr-0059-acts-2-3-and-replay-simplifications, pdr-0061-action-bar-appears-end-of-act-2, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0042-calendar-and-cut-order-validated]
tags: [pdr, decision, acte-2, mutation, comparaison, fr-17]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0064 — Acte 2 (J4) : détails de la transformation sur place

> **En bref.** La fiche est muette sur la manière dont l'acte 2 transforme les surfaces ; la boucle tranche cinq détails sous la règle permanente pdr-0062 et les signale au porteur, qui peut les contester. Aucun ne touche le périmètre, la mise en scène des actes, le budget ni les fournisseurs.

Part de l'assistant : décision prise sur délégation (pdr-0062), contestable par le porteur.

## Contexte
008 (J4) réalise FR-07 (« Concentre-toi sur Android et compare avec la 3.3 », S-02) sur le registre de canevas du backend voulu par [pdr-0058](pdr-0058-backend-canvas-registry-survives-voice-sessions.md). La fiche fixe le résultat (surfaces à leur place, Android seul, comparaison 3.3, [pdr-0024](pdr-0024-act2-android-only.md), [pdr-0059](pdr-0059-acts-2-3-and-replay-simplifications.md)) mais pas le moyen.

## Hypothèses
- ✅ Fiche muette sur ces détails ; ni périmètre, ni mise en scène, ni budget, ni fournisseur.
- ⚠️ Hypothèse non confirmée : la demande transmise aux agents est la **transcription d'entrée du speaker** depuis la délégation précédente (la délégation ne transporte aucun texte) ; une délégation peut couper la phrase en deux (« Concentre-toi sur Android » puis « et compare avec la 3.3 », la seconde moitié serait refusée) ; les agents sont sans état. À vérifier à l'essai réel (J7, instructions vocales, pdr-0037) ; suivi en Q-74.

## Décision
- **D1 — Mutation par données seules** : sur une surface déjà active, l'agent n'émet que `updateDataModel` (chemin entier de la surface, jamais un sous-chemin) ; `createSurface` et `updateComponents` ne sont émis que si la surface manque. Le message du protocole et le contour pointillé de 007 désignent la surface mutée ; aucun squelette n'est repeint.
- **D2 — Comparaison dans les composants existants** (pdr-0014 : ni Comparatif ni Timeline) : l'Indicateur clé et le Sentiment des avis lisent le champ facultatif `comparison {label, value, delta}` déjà réservé par le contrat ; la Courbe de tendance reçoit deux séries nommées « Android 3.4 » et « Android 3.3 » ; la Checklist garde sa forme (la valeur de chaque critère cite la 3.3).
- **D3 — Grammaire des demandes des agents** : une plateforme (Android ou iOS, jamais les deux) et/ou une comparaison avec la 3.3. La 3.3 n'existe que pour Android dans le jeu figé : « compare avec la 3.3 » sans Android est refusé honnêtement (état `rejected`). Toute autre version est refusée.
- **D4 — FR-17 en deux temps (coupe C7 partielle, pdr-0042)** : 008 livre la **correction de plateforme sur surfaces existantes** (« non, plutôt iOS » → les quatre surfaces passent sur les données iOS, sans canevas vide ni recréation). L'**arrêt de la voix et l'annulation de la génération en vol** (« l'IA se tait », S-07, FR-14) restent à J7 avec le barge-in. S-07 n'est donc pas encore vert ; il le devient à J7.
- **D6 — Remise à vide au démarrage de l'app (mode vivant)** : avec D1, une mutation visant une surface que l'app ne connaît pas est refusée (`unknown_surface`). L'app, vide au démarrage, demande donc une fois `POST /canvas/reset` avant la première session voix (invisible : le canevas est déjà vide ; aucune requête en mode rejeu).
- **D7 — Vue iOS et `comparison` incomplet** : la vue iOS de la correction (FR-17) est définie dans [p-fn-dataset](../functional/dataset.md) (GO iOS, une série, 3 extraits iOS, sans comparaison) ; un `comparison` incomplet omet seulement sa ligne (le reste du composant est rendu) ; la couleur de la ligne de comparaison est neutre, jamais déduite du texte du `delta` (RG-09).
- **D8 — Couleurs de séries de la courbe** : stables **par plateforme** (préfixe du nom de série : iOS, Android), tirées d'une palette de graphique sans couleur de statut ; la série de la 3.3 est tracée en pointillés dans la teinte de sa plateforme (RG-09, lisibilité de la comparaison).
- **D9 — Mesures dans une demande** : un décimal n'est pas une version quand « note », « notes » ou « moyenne » figure dans les quatre mots qui le précèdent (« la note Android est à 3,7 »), sauf si le mot juste avant est « la », « version », « release » ou « v » (« la note de la 3.5 » reste refusée) ; unités reconnues : %, pt(s), point(s), étoile(s), « sur 5 », « / 5 », millions, milliers.
- **D5 — Barre d'actions** : [pdr-0061](pdr-0061-action-bar-appears-end-of-act-2.md) la fait apparaître à la fin de l'acte 2 ; elle n'a pas de schéma avant J5 (FR-08) et reste hors de 008.

## Raisons
- D1 : « les surfaces existantes restent à leur place » (S-02) et « aucune surface recréée dans le journal » (roadmap J4) ; le contrat du catalogue impose de réécrire le chemin entier.
- D2 : pdr-0014 écarte tout composant de comparaison ; le champ `comparison` est déjà au contrat.
- D3 : le jeu de référence ne contient que Android 3.3 ([p-fn-dataset](../functional/dataset.md)) ; ne rien inventer (NFR-08).
- D4 : l'annulation en vol dépend de la détection d'interruption (Q-40 à Q-42, J7).

## Options écartées
- Renvoyer `updateComponents` à chaque mutation : bruit sans effet, risque de réinitialiser l'état de rendu.
- Créer un composant « Comparatif » : contre pdr-0014.
- Livrer l'annulation en vol en J4 : sans détection d'interruption, ce serait une simulation.

## Conséquences
- [p-fn-catalog](../functional/catalog.md), [p-fn-dataset](../functional/dataset.md) et [p-fn-dataset-acts](../functional/dataset-acts.md), [p-ar-agents-protocols](../architecture/agents-protocols.md), [p-ar-app-channel-contract](../architecture/app-channel-contract.md) : complétés à la clôture de 008 (2026-10-30).
- `specs/progress.md` : signalé au porteur (D4 en particulier).

## Réexaminer si
- le porteur conteste l'un des détails, ou si la répétition montre que la comparaison ne se lit pas à la projection.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée sous la règle permanente pdr-0062 (fiche muette, détails d'interface et de mécanisme ; C7 déjà validée par pdr-0042). | Assistant (délégation du porteur, pdr-0062) |
| 2026-10-30 | Clôture de 008 : D1 à D9 livrés et vérifiés (`gate --full` vert, capture `app-smoke act2-replay` conforme) ; documents `product/` complétés ; hypothèse de la demande coupée en deux suivie en Q-74. Aucun changement de décision. | Assistant (clôture de 008) |
