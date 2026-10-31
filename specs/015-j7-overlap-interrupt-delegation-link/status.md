# 015 — État

- **Étape** : Gherkin
- **Tentatives** : 1/3
- **Tâche en cours** : T01 (Flutter), T02, T03 (Go) — Gherkin
- **Fichiers touchés** (tâche en cours) : Flutter : `apps/genesis_canvas/test/acceptance/acte_chevauchement_liaison*` et `step/` ; Go : `backend/orchestrator/acceptance/overlap_*`
- **Branche** : feat/015-j7-overlap-interrupt-delegation-link
- **Backlog** : EP-02, EP-06, EP-04, EP-01
- **Mis à jour** : 2026-10-31

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-31 | Définir | `spec.md` (lot B chevauchement Go, lot A app et liaison de délégation), `plan.md`, `tasks.md` (T01-T24 + clôture), [pdr-0080](../../product/decisions/pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided.md) (pdr-0062) ; fonctionnalité « 011b » de [pdr-0077](../../product/decisions/pdr-0077-011b-overlap-interrupt-delegation-link.md) numérotée 015 | commit `specs/015-*` |
| 2026-10-31 | Revue du plan | `architect-reviewer` (Opus, mode PLAN) : **À AMENDER** (2 bloquants P1 garde « l'IA parle » (flux de sortie continu : seuil de niveau, verrouillage à l'ouverture de l'énoncé), P2 jetons fermés et écho par concaténation ; 6 importants P3 priorité et anti-rebond asymétrique, P4 `at_ms` au premier delta et correction qui coupe la voix, P5 cas du commentaire sur sa propre demande, P6 orbe hors `Speaking`, P7 liaison (boucle d'animation, jeton, mesure), P8 témoins positifs, défaut du code coupé, rejeu des suites 011/014). Tous intégrés dans `spec.md`, `plan.md`, `tasks.md`, pdr-0080 | commit `specs/015-*` |

## Revue d'architecte
Revue du plan (P1 à P8) : voir le journal ci-dessus ; amendements appliqués. Conflits avec une décision : aucun.

## Questions pour le porteur
- **Non bloquante (P5)** : un commentaire du speaker (« super », « ok ») par-dessus l'accusé de **sa propre** demande en vol déclenche le chevauchement et annule cette demande (pdr-0077 : « délégations en vol annulées ») ; sans nouvelle délégation (Q-87) le canevas reste interrompu. Atténué par la liste de mots ignorés du compose ; à juger en répétition.
- Aucune autre. Q-80 (horloges, latence) reste à observer en répétition ; les seuils de `VOICE_OVERLAP_*` sont des valeurs de départ.
