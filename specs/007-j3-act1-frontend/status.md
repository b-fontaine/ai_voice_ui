# 007 — État

- **Étape** : Gherkin
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/007-j3-act1-frontend
- **Backlog** : EP-03, EP-04, EP-05, EP-08
- **Mis à jour** : 2026-10-30

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Définir | `spec.md`, `plan.md`, `tasks.md` rédigés. 007 débloquée par les décisions du porteur du 2026-10-30 (pdr-0053 à pdr-0062). Détails d'interface tranchés par la boucle sous pdr-0062 (D1 à D6 de `spec.md` : indicateur d'acte réglé au clic, pointillé = contour de la surface, zone Rejeu en emplacement, remise à vide par bouton + `POST /canvas/reset`, rail à roster fixe, rendu par `CustomPainter`). Ajout d'une petite tâche Go (route de remise à vide) : pdr-0058 exige que la remise à vide réinitialise le registre backend, absent aujourd'hui. | `git log feat/007-j3-act1-frontend` |
| 2026-10-30 | Revue du plan | architect-reviewer (Opus, mode PLAN) : **À AMENDER** (3 bloquants, 5 importants). Amendements A1 à A8 intégrés dans `plan.md` (bloc « Amendements », prioritaire) et `tasks.md` (T05 ajoutée ; fixtures de V1/V5/H-02/H-03 migrées dans T12 et non plus T02 ; T04/T17 Go renforcées). Un seul ajustement de la boucle : D5 « roster fixe » devient « pas de nom codé en dur » (A4c). Passage à Gherkin (T01, T02, T05 d'abord, puis T03 et T04). | commit de cette étape |
| 2026-10-30 | Gherkin | T01 faite (5 paquets squelettes `entity_catalog`, `shared_design_system`, `feature_protocol_feed`, `feature_catalog_shelf`, `feature_stage_controls` ; test d'architecture du workspace rouge puis vert ; aucune règle existante violée). T04 faite (G7, 6 tests dans `backend/orchestrator/acceptance/canvas_reset_test.go`) : rouge attendu `POST /canvas/reset = 404, attendu 204/409/415/403/413` (route absente) ; le cas « Host non autorisé » est déjà vert (garde existant). Le cas « remise à vide pendant l'étape plan » reste aux tests unitaires de `Pipeline` (T17). Reste : T02, T05, T03. | `.omc/state/loop/gates/20261030-092915-unit-go.log`, `.omc/state/loop/gates/20261030-092930-unit-flutter.log` |
| 2026-10-30 | Gherkin | T02 faite : le faux backend émet l'acte 1 `genesis` depuis `contracts/a2ui/genesis/v1/examples` (`emitGenesisAct1`, plan + 3 agents + 4 surfaces en trois temps), route `POST /canvas/reset` (204, compteur, `deleteSurface` triés de l'orchestrateur) ; 9 fixtures négatives `contracts/a2ui/genesis/v1/invalid/` + `expected.json` (rejouées sur une copie du validateur Go : tous refusés avec le code attendu) ; script `testing/backend_fakes/tool/gen_replay.dart`. Rouge initial : symboles absents (`canvasResets`, `ContractFixtures`, `emitGenesisAct1`). **Choix : le validateur Dart (T12) reprend les noms de codes du validateur Go** (`component_not_allowed`, `bad_property`, `bad_catalog`, `surface_limit`, `unknown_surface`, `too_large`, `bad_pointer`) pour garantir la parité ; l'asset de rejeu versionné n'est pas encore changé (T12). | `.omc/state/loop/gates/20261030-093459-unit-flutter.log` |
| 2026-10-30 | Gherkin | T05 faite : `shared_design_system` (`SceneTheme` ThemeExtension, `SceneStatus.fromCode`, `DsSkeleton` statique par défaut, `DsNeutralState`, `DsStatusChip`) ; contrastes WCAG mesurés ≥ 8,36:1 sur toutes les paires, toutes les tailles de texte ≥ 24 px. Rouge initial : `Undefined name 'SceneTheme'`. Reste : T03. | `.omc/state/loop/gates/20261030-093820-unit-flutter.log` |

## Revue d'architecte
### Revue du plan (mode PLAN, 2026-10-30) — verdict : À AMENDER
- [x] **A1 bloquant** — squelette peint par `CanvasBoard` (le `defaultBuilder` de genui 0.10.4 ne s'affiche jamais) ; liaison par `BoundObject`, jamais `dataContext.subscribe` dans un builder.
- [x] **A2 bloquant** — `GenesisMessageValidator` à état dans `entities/catalog`, une instance dans le flux unique (direct et rejeu), compensation locale, codes fermés.
- [x] **A3 bloquant** — `POST /canvas/reset` : port `CanvasResetter`, sessions suivies par `Manager`, 409 si délégation en cours, `Registry.Reset` déterministe, G7 sous `-race`.
- [x] **A4 important** — un coordinateur `_resetStage()` dans la page, rail sans nom codé en dur, transformers, ordre de fermeture, test d'architecture du workspace.
- [x] **A5 important** — égalité `GenesisContract`/`catalog.json`, zéro erreur moteur, fixtures négatives partagées Go/Dart, asset de rejeu dérivé, `catalogId` = compose.
- [x] **A6 important** — route : JSON exigé (415), `Origin` refusé (403), corps ≤ 1 Kio (413), pas de CORS ; délai injecté.
- [x] **A7 important** — emplacements déterministes (2 × 2 / 3 × 2), budget des zones, `maxLines` + ellipse, test de page à 1920 × 1080.
- [x] **A8 important** — migration des acceptations dans T12 (même commit que le catalogue fermé), règles anti-affaiblissement, T05, périmètre Widgetbook/goldens dit explicitement.

## Questions pour le porteur
Aucune bloquante. Signalées sans bloquer (pdr-0062) : D1 à D6 de `spec.md` ; la route Go `POST /canvas/reset` ajoutée au périmètre de 007 ; la survie du canevas d'une session voix à l'autre reste à J4.
