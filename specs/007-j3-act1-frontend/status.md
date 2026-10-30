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
