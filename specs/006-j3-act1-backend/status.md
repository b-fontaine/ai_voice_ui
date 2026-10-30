# 006 — État

- **Étape** : TDD
- **Tentatives** : 1/3
- **Tâche en cours** : T10
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/006-j3-act1-backend
- **Backlog** : EP-03, EP-04 (contrat), EP-09
- **Mis à jour** : 2026-10-30 (revue du plan intégrée)

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Définir | `spec.md`, `plan.md`, `tasks.md` rédigés. J3 est coupé en deux : 006 (backend : jeu de données, catalogue `genesis` côté contrat, trois agents, orchestrateur) et 007 (Flutter : catalogue côté client, Q-71, étagère, rail, panneau protocole, remise à vide), car Q-22, Q-30, Q-31, Q-35, Q-44, Q-17, Q-69, Q-71 attendent le porteur (échéance 2/11) et aucune ne concerne le backend de façon bloquante (`catalogId` déjà un paramètre, composition déterministe derrière `Composer`). | `git log feat/006-j3-act1-backend` |
| 2026-10-30 | Revue du plan | architect-reviewer (Opus, mode PLAN) : **À AMENDER** (1 bloquant, 6 importants, mineurs). A1 vérifié dans le code (`pipeline.go:204-217` lance tous les agents ; `executor.go` : `rejected` après `submitted` devient `failed`). Amendements A1-A8 intégrés dans `plan.md` (bloc « Amendements de la revue », prioritaire), `tasks.md` (T05, T06, T15a-c ajoutées, ordre corrigé) et `spec.md` (G2, G2bis, latences). | commit de cette étape |
| 2026-10-30 | Gherkin (préparation) | T05 faite : déplacement pur `backend/agents/quality` → `backend/agents` (module, imports, Dockerfile `ARG AGENT`, compose, CI). Rouge initial attendu : `go build ./...` échoue (`no required module provides package …/backend/agents/quality/internal/{agent,compose,dataset}`). Écarts : deux chemins relatifs de tests (un niveau de moins), une chaîne de filtre de `TestNoFileAccess` ; aucune assertion modifiée. `gate --unit go` et `--full` verts (40 contrôles). | `.omc/state/loop/gates/20261030-020503-unit-go.log`, `…/20261030-020506-full.log` |
| 2026-10-30 | Gherkin (préparation) | T06 faite : fixtures `contracts/a2ui/genesis/v1/` (`catalog.json`, 4 exemples en trois temps, README) et test vert `genesis_fixtures_test.go` (rouge initial : fixtures absentes). Choix de l'agent : `catalog.json` en format maison (pas JSON Schema) ; avis en nombres bruts (`count`, `positivePct`, `negativePct`, `average`) ; `levelLabel` ajouté aux items de checklist. | `.omc/state/loop/gates/20261030-020810-unit-go.log` |
| 2026-10-30 | Gherkin | T01-T03 faites : G1, G1bis, G2, G2bis, G3 (`backend/orchestrator/acceptance/genesis_*_test.go`, vrais binaires compilés à la demande, sans `TestMain`). **Sortie rouge attendue** : G1, G1bis, G2, G3 : `compilation de agent-voice impossible (le binaire d'agent doit exister) : go build ./cmd/agent-voice : exit status 1` ; G2bis : `aucun message plan publié ; reçu activity(Qualité:working), activity(Qualité:failed)` (vrai défaut : pas de planificateur, le refus devient `failed`). Tests de 004 toujours verts. Hypothèses des tests : `plan.data = {delegation, selected, idle}` (noms ou objets `name`/`agent`), `plan` en tête d'une délégation ; mots de refus et d'alternative de `out_of_catalog` testés par mots-clés (la phrase n'existe pas encore). Dette mineure : le dossier temporaire des binaires n'est jamais supprimé (`/tmp/genesis-agents-*`). | `.omc/state/loop/gates/20261030-021221-unit-go.log` |
| 2026-10-30 | Gherkin (clôture) | T04 faite : G4 (`backend/agents/acceptance/genesis_agents_test.go`, vrais binaires). **Sortie rouge attendue** : Qualité : `3 messages A2UI, attendu 6 (surfaces [kpi trend])` (émet encore la surface 004 `quality`, `Column`/`Text`) ; refus Qualité cite « J2 » ; `surfaces actives vides : 0 createSurface, attendu 2` ; Voix du client et Livraison : `compilation de agent-voice impossible` / `agent-delivery`. B4 (004) reste vert. **Étape Gherkin terminée** : G1, G1bis, G2, G2bis, G3, G4 rouges pour la bonne raison, `gate --unit go` vert sur arbre propre. Suite : TDD, T10 d'abord (noyau `internal/kit`), puis T11, T12, T13, T14, T15a-c, T16. | `.omc/state/loop/gates/20261030-021436-unit-go.log` |

## Revue d'architecte
**Revue du plan (2026-10-30) : À AMENDER.** Amendements, tous intégrés au plan (voir `plan.md`) :
- [x] A1 bloquante — l'orchestrateur choisit les agents (`Planner`, tags de carte, message `plan`, état `rejected`, `out_of_catalog`) ; pdr-0013, RG-29
- [x] A2 importante — registre de l'orchestrateur = source de vérité (`ActiveSurfaces`), fin de la mémoire par contexte
- [x] A3 importante — contrat exécutable (fixtures `contracts/a2ui/genesis/v1/`, codes `ok|risk|blocking`, nombres, champs acte 2 réservés, `sendDataModel: false`)
- [x] A4 importante — validateur de propriétés (`bad_property`), liste blanche J3 = 4 composants
- [x] A5 importante — ordre des tâches (déplacement pur d'abord, T06, T15a-c)
- [x] A6 importante — échec partiel honnête (`partial_failure`, résumés ≤ 200 runes)
- [x] A7 importante — vrais binaires en acceptation, instructions vocales v1
- [x] A8 mineures — latences, mots entiers, arrondis, Dockerfile, `check-compose.sh`

## Questions pour le porteur
À confirmer par le porteur, sans bloquer 006 (conflits relevés par la revue) : (1) pdr-0023 (LLM guidé par exemples) contre la composition déterministe provisoire de 006 (Q-17 ouverte ; les fixtures `contracts/a2ui/genesis/v1/` servent d'exemples d'écrans) ; (2) remise à vide (007, FR-11) : recommandation = fermer la session voix (pdr-0052), sinon le hub rejoue les surfaces (lié à Q-70). Pas de nouvelle `Q-xx` ouverte par la boucle. Déjà ouvertes et sans effet bloquant ici : Q-44 (valeur provisoire du `catalogId` en variable d'environnement), Q-17 (LLM de composition, reporté), Q-35, Q-69 (retrait provisoire conservé). Bloquantes pour 007 (client / écran) : Q-71, Q-22, Q-30, Q-31.
