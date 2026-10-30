# 006 — État

- **Étape** : Gherkin
- **Tentatives** : 1/3
- **Tâche en cours** : T05
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/006-j3-act1-backend
- **Backlog** : EP-03, EP-04 (contrat), EP-09
- **Mis à jour** : 2026-10-30 (revue du plan intégrée)

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Définir | `spec.md`, `plan.md`, `tasks.md` rédigés. J3 est coupé en deux : 006 (backend : jeu de données, catalogue `genesis` côté contrat, trois agents, orchestrateur) et 007 (Flutter : catalogue côté client, Q-71, étagère, rail, panneau protocole, remise à vide), car Q-22, Q-30, Q-31, Q-35, Q-44, Q-17, Q-69, Q-71 attendent le porteur (échéance 2/11) et aucune ne concerne le backend de façon bloquante (`catalogId` déjà un paramètre, composition déterministe derrière `Composer`). | `git log feat/006-j3-act1-backend` |
| 2026-10-30 | Revue du plan | architect-reviewer (Opus, mode PLAN) : **À AMENDER** (1 bloquant, 6 importants, mineurs). A1 vérifié dans le code (`pipeline.go:204-217` lance tous les agents ; `executor.go` : `rejected` après `submitted` devient `failed`). Amendements A1-A8 intégrés dans `plan.md` (bloc « Amendements de la revue », prioritaire), `tasks.md` (T05, T06, T15a-c ajoutées, ordre corrigé) et `spec.md` (G2, G2bis, latences). | commit de cette étape |

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
