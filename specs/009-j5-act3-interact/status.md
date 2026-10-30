# 009 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/009-j5-act3-interact
- **Backlog** : EP-03, EP-04, EP-02, EP-06
- **Mis à jour** : 2026-10-30 15:15

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Définir | `spec.md`, `plan.md`, `tasks.md` rédigés ; **pdr-0065** (D1 à D6, détails tranchés sous pdr-0062) créée et indexée ; **Q-75** ouverte (voix hors délégation, non bloquante, avant J7) ; `product_lint` 0 erreur. Périmètre : FR-08 complet (S-03, RG-18, RG-28, RG-30), Barre d'actions en cinquième surface à la fin de l'acte 2 (pdr-0061). | `python3 -I product/_tools/product_lint.py` : 0 erreur |
| 2026-10-30 | Revue du plan | architect-reviewer (Opus, mode PLAN) : **À AMENDER** (3 bloquants, 3 importants, 1 mineur…). Amendements A1 à A8 intégrés dans `plan.md` (bloc « Amendements », prioritaire) et `tasks.md` (T06 régressions de 008, T17 `CanvasBoard`, T14 refaite, T16 avant T15) ; pdr-0065 amendée (D5, D7) ; **Q-76** ouverte. | verdict ci-dessous |
| 2026-10-30 | Gherkin | T01 faite (`9889631` : `dataset.json` `decisions`, `Dataset.Decision`) ; T02 faite (`58243eb` : `ActionBar` au contrat, 5 `components`, fixtures `act2-actions` et `act3-*`, README du contrat, `GenesisContract` Dart, `actionBarItem` minimal, compose à 5 composants, tests de 008 liés au catalogue corrigés à force égale) ; fixtures négatives `ActionBar` non ajoutées dans `invalid/` (les validateurs ne contrôlent pas le data model ; tests de widget à la place, parité à décider en T15). | `.omc/state/loop/gates/20261030-144817-unit-go.log`, `…144820-unit-flutter.log` : VERT |
| 2026-10-30 | Gherkin | **T03 et T04 faites — étape Gherkin terminée.** T03 (Go, `backend/orchestrator/acceptance/act3_*_test.go`, `a44ee4f`) : S-03, C1 ×2, C2 ×3, C3 ×3, C4 ×2, C5 ×4 ; rouges pour la bonne raison : `POST /canvas/actions = 404` (route absente) pour tous sauf C2 (`acte 2 : createSurface = [], attendu [actions] seule`, `0 failed et 3 completed, attendu Livraison failed…`) ; `TestAct3_C2_IOSCorrectionDoesNotRecreateActions` passe (garde de non-régression) ; assertions « zéro createSurface » de 008 restreintes aux quatre surfaces (helper `createdAmong`). T04 (Flutter, `acte3_interagir.feature`, `26f8392`) : S-03, C1 ×2, C3 ×3, C6 ×3, A1 : rouges : `aucune requête POST /canvas/actions reçue par le faux backend` (boutons `onPressed: null`), `les deux boutons de la Barre d'actions doivent être actifs`, `la Barre d'actions n'est pas sous la grille` (654 attendu ≥ 914) ; le scénario C6 « état neutre » ne rougit que par le débordement de la grille à 5 surfaces (`RenderFlex overflowed by 39 pixels`) et verdira avec T17 seul. `gate --unit` (Go et Flutter) VERT, 54 contrôles, arbre propre. Reste à traiter en T06 : `requireOnlyUpdates`, `requireAttribution`, `len(got) != 4` de 008, `delivery/views_test.go`. | `.omc/state/loop/gates/20261030-150559-unit.log` : VERT |

## Revue d'architecte

### Revue du plan (mode PLAN, 2026-10-30) — verdict : À AMENDER
- A1 [bloquant] 5ᵉ surface : une grille 3×2 déplacerait les quatre surfaces (S-02, B1, B2 rouges) → bandeau hors grille (D7), `CanvasBoard` stable, T17.
- A2 [bloquant] régressions de 008 non planifiées (`views_test.go`, `genesis_agents_test.go`, `act2_*`, `check-compose.sh`, `genesis_catalog_test.dart`) → T06, compose dans T02, cas C2 en échec.
- A3 [bloquant] voix : pas de délégation à l'acte 3 (une session par acte) ; `delegation_id` nul documenté par le SDK ; jamais de renvoi sur silence ; consigne propre à l'orchestrateur → D5 amendé, T14.
- A4 [important] `Manager.Act` atomique sous `Canvas.mu`, `Delegation.Action`, `act-n` jamais passé au fournisseur → T12.
- A5 [important] validation synchrone sans réseau, message A2A sans champ du client, part texte, rejet côté agent → T10, T11, T13.
- A6 [important] état `Running` du Bloc d'action jusqu'au résultat, client à un seul essai → T16.
- A7 [important] ordre T16 avant T15, `catalog_shelf` sans code, T05 test de garde, exception de sous-chemin documentée.
- A8 [mineur] `ActionResultTemplate`, `sanitizeSummary`, limite « décision perdue » décrite par un test, Q-76.
- Faits vérifiés par l'architecte : genui 0.10.4 `Surface` accepte `actionDelegate` ; `DataModel.set` notifie les ancêtres (T05 devrait passer) ; openai-go v3.90.0 `CommentaryAppendEventParam.DelegationID` nullable ; a2a-go refuse un message sans part.
- Conflits avec une décision : aucun à remonter ; `agents-protocols.md` § Acte 3 (WSS) à mettre à jour à la clôture (T92).

## Questions pour le porteur
- **Q-75** (non bloquante, avant J7) : GPT-Live dit-il un texte hors délégation ? Hypothèse non confirmée ; essai réel unique à la vérification ; repli honnête si la voix reste muette.
- **Q-76** (non bloquante, avant J7) : la décision « Bloquée » est perdue par une demande vocale ultérieure (agent sans état) ; reco : accepter la limite pour la démo.
