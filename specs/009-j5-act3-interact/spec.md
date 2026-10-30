# 009 — J5 : acte 3 « Interagir » (Barre d'actions, clic → agent Livraison → vrai résultat → voix)

> **En bref.** À la fin de l'acte 2, une cinquième surface, la **Barre d'actions**, apparaît avec la recommandation NO-GO Android (pdr-0061). Le speaker clique sur « Bloquer la release » : l'app transmet un événement typé au backend, l'orchestrateur le confie à l'agent **Livraison** (qui s'allume dans le rail), l'agent répond par un **vrai résultat**, le statut de la checklist passe à **« Bloquée »**, puis seulement alors la voix confirme. « Valider la release » fait de même (« Validée », pdr-0016).

- **Jalon** : J5 « Acte 3 Interagir » (`product/roadmap/roadmap.md`), backlog EP-03 (agents), EP-04 (A2UI), EP-02 (voix), EP-06 (action).
- **Exigences visées** : FR-08 (Must), FR-03 ; RG-18, RG-28, RG-30, RG-25, RG-29, RG-10, RG-09 ; NFR-06, NFR-08.
- **Décisions applicables** : pdr-0005, pdr-0014, pdr-0016, pdr-0017, pdr-0019, pdr-0053, pdr-0054, pdr-0058, pdr-0059 (Q-49 : pas de confirmation), pdr-0061, pdr-0062, pdr-0064, **pdr-0065** (D1 à D6) ; ADR hérités (hexagonal Go, Bloc, FSD).
- **Hors périmètre** : rejeu et enregistrement (J6, acte 4) ; arrêt de la voix, annulation en vol, « l'IA se tait » (J7) ; `CrashList` ; confirmation modale (pdr-0059) ; raccourci clavier des boutons (pdr-0033) ; composeur par LLM (Q-17).

## Décisions prises par la boucle (pdr-0062 → pdr-0065, à signaler au porteur)
Voir `product/decisions/pdr-0065-009-act3-interact-details-assistant-decided.md`.
- **D1** clic transmis par `POST /canvas/actions` (HTTP, gardes de `/canvas/reset`) ; **D2** Barre d'actions = cinquième surface `actions`, créée par Livraison à la fin de l'acte 2 ; **D3** résultat = `updateDataModel` du sous-chemin `/checklist/decisionStatus` ; **D4** routage par tags de carte `action:<nom>` ; **D5** voix hors délégation (`Announce`, stratégies essayées dans l'ordre, **hypothèse Q-75**) ; **D6** boutons inactifs pendant l'action, rejouable ensuite.
- ⚠️ **Q-75** : GPT-Live dit-il un texte hors délégation ? Non vérifié ; un seul essai réel à la vérification. Le repli est honnête : rien d'inventé, l'écran a changé quand même.

## Scénarios (Gherkin)
- **S-03 — Acte 3 « interagir avec un composant généré »** (`product/functional/features/voice-screen-generation.feature`, repris tel quel) : automatisé en Flutter sur le faux backend (actes 1 et 2 depuis les fixtures, puis clic) **et** en Go (`acceptance`, vrais agents Qualité, Voix du client et Livraison derrière l'orchestrateur, sideband factice) :
  - « l'agent Livraison s'allume dans le rail » : `plan` (selected = Livraison, les deux autres en veille) puis `agent.activity working` puis `completed` ;
  - « l'IA confirme à la voix » : un seul `Announce`, **après** `completed`, dont le texte vient du résumé réel de l'agent ;
  - « le statut de la checklist passe à « Bloquée » » : le `decisionStatus` affiché passe de « En attente de décision » à « Bloquée » ; critères, recommandation (NO-GO Android) et comparaison 3.3 inchangés.
- **Scénarios propres à 009** (fichiers `.feature` hors les 9 de la fiche, pdr-0049) :
  - **C1 — Valider (RG-30, pdr-0016)** : « Valider la release » → « Validée », mêmes étapes ; « Bloquer » puis « Valider » → « Validée » (la décision humaine prime).
  - **C2 — Barre d'actions à la fin de l'acte 2** : la surface `actions` est créée dans la tâche Livraison de l'acte 2 (plan, `createSurface`, `updateComponents`, `updateDataModel`), jamais avant ; les quatre surfaces de l'acte 1 ne sont ni recréées ni supprimées ; l'étagère indique « 5 / 6 ». Si la surface existe déjà (correction iOS), aucune recréation.
  - **C3 — Refus honnêtes** : action inconnue, surface qui ne la porte pas, corps illisible → 422/400, rien de modifié ; aucune session voix ouverte → 409 `no_session` ; délégation en cours → 409 `busy` ; l'app réessaie (borné) puis laisse les boutons actifs.
  - **C4 — Vrai résultat** : agent injoignable, en échec ou résultat invalide → checklist **inchangée**, `agent.activity failed`, phrase d'échec honnête dite, **jamais** « Bloquée » annoncé ; aucune confirmation avant `completed`.
  - **C5 — Voix hors délégation (D5)** : stratégie 1 refusée (erreur d'acquittement) → stratégie 2 ; aucune ne fait parler la voix dans le délai → journal, pas de faux transcript ; fermeture de session pendant l'action → rien n'est dit.
  - **C6 — Rendu de la Barre d'actions (app)** : trois états (squelette, sans données, neutre) ; deux boutons ≥ 24 px, cibles ≥ 48 px ; boutons inactifs pendant l'action ; libellés de la donnée ; couleur par `tone` (code fermé), jamais par libellé.
- Les scénarios de 000, 005, 007 et 008 restent **verts**. Les assertions « aucun `createSurface` » de 008 (S-02, B1, B2) se **restreignent aux quatre surfaces de l'acte 1** (la création de `actions` est attendue, D2), sans affaiblir le reste.

## Critères d'acceptation
- [ ] S-03 (Flutter et Go), C1 à C6 automatisés et verts ; scénarios antérieurs toujours verts
- [ ] Contrat `contracts/a2ui/genesis/v1/` : `ActionBar` avec schéma (cinq composants `components`), fixtures `act2-actions.jsonl` et `act3-*.jsonl` produites à l'identique par le composeur Livraison et rejouées par le validateur client et le moteur genui (parité Go/Dart)
- [ ] Mise à jour par sous-chemin vérifiée sur genui 0.10.4 : `BoundObject` de `/checklist` se reconstruit sur `updateDataModel /checklist/decisionStatus` sans recréer la surface (sinon repli du plan)
- [ ] Libellés « Bloquée » / « Validée » lus dans le jeu de données (`dataset.json`), pas codés dans le composeur
- [ ] Tests unitaires de chaque unité nouvelle (action dans le jeu de données, composeur Livraison, planificateur d'action, exécution d'une action, route HTTP, `Announce`, `CatalogItem`, `ActionBloc`)
- [ ] `tools/loop/gate.sh --full` vert (Flutter et Go)
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] `app-smoke.sh` : capture de l'acte 3 (rejeu des fixtures actes 1, 2, 3), Barre d'actions et « Bloquée » lisibles, texte ≥ 24 px
- [ ] Essai réel unique (budget, `openai-budget.sh check`) : acte 1, acte 2, clic ; consigne dans `knowledge/` la stratégie qui a fait parler la voix (Q-75) ; si indisponible (pas de micro), noté dans `status.md`

## Questions ouvertes
**Q-75** (non bloquante, avant J7) : la voix dit-elle un texte hors délégation ? Q-40 à Q-42, Q-67, Q-68, Q-74 restent à J7. ⚠️ Hypothèse non confirmée : « Bloquer » depuis un clic ne crée pas de délégation GPT-Live ; le rattachement à la dernière délégation est une hypothèse d'implémentation (Q-75).
