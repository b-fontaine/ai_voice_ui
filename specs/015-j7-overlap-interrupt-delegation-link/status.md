# 015 — État

- **Étape** : TDD
- **Tentatives** : 1/3
- **Tâche en cours** : Flutter T10, T14, T11, T12a, T12b
- **Fichiers touchés** (tâche en cours) : Go : `backend/orchestrator/internal/{domain,app/voice,bootstrap}` ; Flutter : `packages/entities/session`, `packages/features/voice_session`, `packages/shared/design_system`, `apps/genesis_canvas/lib/widgets/agents_rail` (listes détaillées au retour des agents)
- **Branche** : feat/015-j7-overlap-interrupt-delegation-link
- **Backlog** : EP-02, EP-06, EP-04, EP-01
- **Mis à jour** : 2026-10-31

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-31 | Définir | `spec.md` (lot B chevauchement Go, lot A app et liaison de délégation), `plan.md`, `tasks.md` (T01-T24 + clôture), [pdr-0080](../../product/decisions/pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided.md) (pdr-0062) ; fonctionnalité « 011b » de [pdr-0077](../../product/decisions/pdr-0077-011b-overlap-interrupt-delegation-link.md) numérotée 015 | commit `specs/015-*` |
| 2026-10-31 | Revue du plan | `architect-reviewer` (Opus, mode PLAN) : **À AMENDER** (2 bloquants P1 garde « l'IA parle » (flux de sortie continu : seuil de niveau, verrouillage à l'ouverture de l'énoncé), P2 jetons fermés et écho par concaténation ; 6 importants P3 priorité et anti-rebond asymétrique, P4 `at_ms` au premier delta et correction qui coupe la voix, P5 cas du commentaire sur sa propre demande, P6 orbe hors `Speaking`, P7 liaison (boucle d'animation, jeton, mesure), P8 témoins positifs, défaut du code coupé, rejeu des suites 011/014). Tous intégrés dans `spec.md`, `plan.md`, `tasks.md`, pdr-0080 | commit `specs/015-*` |
| 2026-10-31 | Gherkin | **Flutter (T01)** : `acte_chevauchement_liaison.feature`, 16 scénarios dont 13 rouges pour la bonne raison (`l'orbe n'est jamais passé à l'état « Écoute » (dernier état : « Interrompue »)` — cause `overlap` traitée comme `stop` ; `la liaison de délégation de l'agent Qualité (delegation-link-Qualité) doit relier l'orchestrateur à sa tuile` — clé absente), 3 gardes verts ; `gate --unit flutter` vert : `.omc/state/loop/gates/20261031-101053-unit-flutter.log`. **Go (T02, T03)** : O-01 à O-08 rouges (`aucun voice.interrupted publié : non atteint`), témoins positifs, gardes 011/014 verts ; rejeu `ACCEPTANCE_OVERLAP=compose go test -tags acceptance -skip 'TestO0' ./acceptance/` vert (101 s) ; `gate --unit go` vert : `.omc/state/loop/gates/20261031-101142-unit-go.log`. Contraintes d'implémentation : la clé `delegation-link-<agent>` doit être sur un widget contenant le tracé, avec une frontière de repeinture ; `planOverlapDefaults` (test) s'efface devant le compose après T24 | `b9792cd`, commit Go |
| 2026-10-31 | TDD (lot B Go) | **T20 à T23 faites** (`CauseOverlap` + `VOICE_OVERLAP_*` validées ; `OverlapFilter` ; `KindOverlap` dans le classifieur avec priorité et anti-rebond asymétrique, `StopConfig.Active()` ; branchement dans `supervise`, cause `overlap` sur le fil `wire.go`) : `gate --unit go` vert `.omc/state/loop/gates/20261031-102323-unit-go.log` ; acceptation O-01 à O-08 verte ; **rejeu T03 de toute l'acceptation Go avec les valeurs du compose** vert (121 s) ; T24 compose (`check-compose.sh` OK). Notes pour la revue : `d'accord` ignore aussi « accord » (découpage par jeton, Q-80) ; un mot de sortie jamais fermé n'entre pas dans l'écho ; `Detection.Speaking` ajouté pour la correction dite pendant que l'IA parle | `b3502e5`, `575cf40` |

## Revue d'architecte
Revue du plan (P1 à P8) : voir le journal ci-dessus ; amendements appliqués. Conflits avec une décision : aucun.

## Questions pour le porteur
- **Écart docs/écran (non bloquant, signalé par T01)** : `product/` dit que le rail est vide pendant le rejeu ; en réel, après un direct, les tuiles terminées y restent affichées. Non tranché ; L-04 teste seulement l'absence de liaison en rejeu.
- **Non bloquante (P5)** : un commentaire du speaker (« super », « ok ») par-dessus l'accusé de **sa propre** demande en vol déclenche le chevauchement et annule cette demande (pdr-0077 : « délégations en vol annulées ») ; sans nouvelle délégation (Q-87) le canevas reste interrompu. Atténué par la liste de mots ignorés du compose ; à juger en répétition.
- Aucune autre. Q-80 (horloges, latence) reste à observer en répétition ; les seuils de `VOICE_OVERLAP_*` sont des valeurs de départ.
