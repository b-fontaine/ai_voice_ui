# 016 — État

- **Étape** : Gherkin
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/016-voice-guard-resume
- **Backlog** : EP-02, EP-06
- **Mis à jour** : 2026-10-31 13:55

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-31 | Définir | `spec.md`, `plan.md`, `tasks.md` : (a) consigne de silence dans les instructions vocales (filtre orchestrateur écarté, raisons au plan), (b) phrase de reprise `repeat_request` pour une demande dégradée par un chevauchement et refusée (`NoteOverlap`, `VOICE_RECOVERY_WINDOW`). Frontière bruit/demande retenue par la boucle sous pdr-0062 et soumise à **Q-90** (non bloquante). « Stop » non transcrit : hors périmètre (aucun signal) | commit `specs/016-*` |
| 2026-10-31 | Revue du plan | `architect-reviewer` (Opus, mode PLAN) : **À AMENDER** (1 bloquant P1 boucle possible de « répétez » si le speaker répète par-dessus la reprise ; 6 importants P2 évaluation au point de refus (la course reste ouverte après `settle`), P3 `NoteOverlap` par le forwarder, P4 pas de refus de démarrage sans chevauchement (retour arrière 015), P5 réutiliser `no_request` (doublon, tutoiement, clé obligatoire cassante), P6 G-01/G-02 mal ciblés (forme et non sujet, textes de 012, `httptest`), P7 interaction bruit délégué/reprise, P8 découpage T12 et scénarios manquants). Tous intégrés : un seul passage (`repeatPending`, marque à usage unique, R-08), `recovery()` évaluée au refus, R-01 à R-11, G-01/G-02 réécrits, T12a/T12b. **Pour le porteur, sans bloquer** : le bruit délégué malgré la consigne reçoit « répétez » (assumé, R-09) | commit `specs/016-*` |

## Revue d'architecte
<!-- Verdict et R1…Rn ; cocher celles appliquées. -->

## Questions pour le porteur
- **Q-90** (non bloquante) : frontière bruit / demande (politesse isolée, question hors release).
