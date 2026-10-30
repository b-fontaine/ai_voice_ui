# 011 — État

- **Étape** : Refactorisation
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/011-voice-interaction
- **Backlog** : EP-02, EP-03, EP-04, EP-06
- **Mis à jour** : 2026-10-30 20:08

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Définir | spec.md, plan.md, tasks.md (17 tâches), pdr-0073 ; `product_lint` 0 erreur | — |
| 2026-10-30 | Revue du plan | `architect-reviewer` (Opus) : À AMENDER (4 bloquants, 4 importants) ; A1-A8 intégrés dans `plan.md`, `tasks.md`, `spec.md`, pdr-0073 ; Q-77 ouverte | `product_lint` 0 erreur |
| 2026-10-30 | Gherkin | T01 Go (K-01 à K-04) : `TestK01_CompareAfterFocusKeepsPlatform` rouge « 0 completed et 3 rejected, attendu 3 completed » ; `TestK02_…` rouge « plan = [Qualité, Voix du client], attendu […Livraison] » ; `TestK03_…` et `TestK04_StopWordsAloneTrigger` rouges « aucun voice.interrupted publié en 10s » (gardes sans stop verts). T02 Flutter : `acte_interruption.feature`, 11 scénarios `+0 -11` (piste distante restée active ; orbe jamais « Interrompue » ; indicateur « Acte 2/3 » absent ; statut tronqué ; bouton « fait » absent). **T03 (spike `flutter_webrtc` Linux) reste à faire avant T21** (manuel). Hypothèses du test : horloge `port.Clock` pour `VOICE_STOP_SETTLE` ; K-07 dimensionné à 1366×768 ; remise du son sur `orb.level` à 0 + 3 s | `gate --unit go` `.omc/state/loop/gates/20261030-203301-unit-go.log` ; `--unit flutter` `…/20261030-203303-unit-flutter.log` |
| 2026-10-30 | TDD | T10 (Go, `764ad28`) : fenêtre de demande, `Take` dans `run` après `REQUEST_WINDOW_SETTLE`, `Delegate` non bloquant ; **écarts tranchés (pdr-0062)** : un delta est dans la demande si `start < offset` ou s'il commence et finit avant `offset + marge` (une marge pure faisait régresser G7/G1bis/B7), la file pleine ne fait plus de `Take` immédiat (le texte d'une délégation refusée peut se retrouver dans la suivante), NFR-02 +300 ms à remesurer. T20 `cd9a3c7`, T23 `e5582ea`, T22 `e8c303e`, T25 `c2dfa9e` (limite connue : un clic sans changement de statut laisse le mémo « en attente » ; le libellé « fait » est produit par le client) | `.omc/state/loop/gates/20261030-205109-unit-go.log`, `…-205501-unit-flutter.log` |
| 2026-10-30 | TDD | T11 `6e33124` (focus : `genesis/intent`, `genesis/focus`, liste blanche écrite en dur dans `a2aclient` ; l'acceptation 008 A6 « compare refusé » est inversée par pdr-0071), T12+T13 `44281c4` (détecteur : `MaxWords` 4 par défaut, liste vide par défaut), T21+T26 `a5d5ccd` (phase de l'orbe ; durée maximale d'interruption 15 s par défaut, `GENESIS_INTERRUPT_MAX_MS`), T24 `8d49d67` (indicateur ; à voir en T91 : le minuteur de 60 s de `CanvasActionBloc` survit à la fermeture de la page), T14 `5bc68d7` (annulation par époque ; `stopped` obligatoire dans `VOICE_PHRASES_FILE`). **T03 (spike) non fait** : manuel, à mener en répétition | `…/gates/20261030-212610-unit-go.log`, `…-212506-unit-flutter.log` |
| 2026-10-30 | TDD (fin) | T15/T17/T18 `789f34f`, T89 `c29ac4b` ; **`gate --full` vert, 58 contrôles** (acceptation Go K-01 à K-04 et Flutter 11 scénarios `acte_interruption` verts). Écarts tranchés : `StopDetector.SettleNow()` (le service confirme au déclenchement du minuteur), `stopSpanMs = 3000` codé en dur dans `manager.go`, K-03 corrigé (clé de phrase `failure`). **T03 reste à faire en répétition** | `.omc/state/loop/gates/20261030-213658-full.log` |
| 2026-10-30 | Revue | `architect-reviewer` (Opus, mode CODE) : **À REFACTORISER** (0 bloquante, 5 importantes R1-R5, 5 mineures R6-R10) | rapport ci-dessous |

## Revue d'architecte
**Mode PLAN : À AMENDER** (4 bloquants : A1 annulation/interblocage `Canvas.mu`, A2 surface inachevée (`Registry.Compensation` trop large), A3 attente dans `Delegate`, A4 focus/intention inconnue de l'orchestrateur ; 4 importants : A5 détecteur, A6 contrat client, A7 `canceled`/clic, A8 ordre/config/S-05). Détail dans `plan.md` § Amendements, tous intégrés.

**Mode CODE : À REFACTORISER** (0 bloquante, 5 importantes, 5 mineures). Lots : **A (Go)** R1 (`StopSpan` + `IsStopOnly` configurables, paquet neutre `internal/app/stopword`), R2 (`MaxWords` effectif mot à mot : confirmer seulement à ponctuation terminale/`Settle`/nouvel énoncé, écarter si `nWords > MaxWords`), R7 (issue typée pour `failLocked`, supprimer `Poll`, `interrupt.go`, coquille hub) ; **B (Go)** R3 (liste blanche de l'intention : forme seulement), R8 (`hasData` et `Complete()`) ; **C (Flutter)** R4 (état « décision prise » dans `CanvasActionBloc`, `CanvasActionScope` sans état), R9 constantes de `release_checklist.dart` ; **D (Flutter)** R5 (`DelegationStarted` daté du « Stop » ignoré, numéro d'interruption), R6 (sorties alignées, `buildWhen`), R10 (`ActionStageReset` au `dispose`), R9 test `ReplayRouter` ignore `voice.interrupted`. Goldens « Acte n/3 » (A8/R9) : **écart acté**, assertions de texte à la place (aucun golden n'existe pour l'indicateur).
- [ ] A  - [ ] B  - [ ] C  - [ ] D
**Conflits avec une décision (pour le porteur, non refactorisés)** : pdr-0073 D2 dit « mots entiers, fenêtre de 6 mots » alors que le code applique A5 (premier mot significatif, `MaxWords`) — à amender par la boucle (pdr-0062), fait à la clôture ; `app-channel-contract.md` en retard sur le code (`canceled` émis, `voice.interrupted`) — T92. Hypothèses non confirmées, à vérifier en répétition : T03 (`track.enabled=false` sous Linux), GPT-Live crée une délégation pour « Stop », même horloge pour `start_ms` de sortie et `at_ms`, double accusé vocal, deltas d'entrée jamais révisés, NFR-02 +300 ms, Q-77.

## Questions pour le porteur
Q-77 (déclencheur d'interruption sur prise de parole) : non bloquante, 011 avance sur le mot d'arrêt seul.
