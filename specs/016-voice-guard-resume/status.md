# 016 — État

- **Étape** : Revue du plan
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/016-voice-guard-resume
- **Backlog** : EP-02, EP-06
- **Mis à jour** : 2026-10-31 13:40

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-31 | Définir | `spec.md`, `plan.md`, `tasks.md` : (a) consigne de silence dans les instructions vocales (filtre orchestrateur écarté, raisons au plan), (b) phrase de reprise `repeat_request` pour une demande dégradée par un chevauchement et refusée (`NoteOverlap`, `VOICE_RECOVERY_WINDOW`). Frontière bruit/demande retenue par la boucle sous pdr-0062 et soumise à **Q-90** (non bloquante). « Stop » non transcrit : hors périmètre (aucun signal) | commit `specs/016-*` |

## Revue d'architecte
<!-- Verdict et R1…Rn ; cocher celles appliquées. -->

## Questions pour le porteur
- **Q-90** (non bloquante) : frontière bruit / demande (politesse isolée, question hors release).
