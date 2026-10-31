# 016 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : T10, T11
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/016-voice-guard-resume
- **Backlog** : EP-02, EP-06
- **Mis à jour** : 2026-10-31 14:05

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-31 | Définir | `spec.md`, `plan.md`, `tasks.md` : (a) consigne de silence dans les instructions vocales (filtre orchestrateur écarté, raisons au plan), (b) phrase de reprise `no_request` pour une demande dégradée par un chevauchement et refusée (`NoteOverlap`, `VOICE_RECOVERY_WINDOW`). Frontière bruit/demande retenue par la boucle sous pdr-0062 et soumise à **Q-90** (non bloquante). « Stop » non transcrit : hors périmètre (aucun signal) | commit `specs/016-*` |
| 2026-10-31 | Revue du plan | `architect-reviewer` (Opus, mode PLAN) : **À AMENDER** (1 bloquant P1 boucle possible de « répétez » si le speaker répète par-dessus la reprise ; 6 importants P2 évaluation au point de refus (la course reste ouverte après `settle`), P3 `NoteOverlap` par le forwarder, P4 pas de refus de démarrage sans chevauchement (retour arrière 015), P5 réutiliser `no_request` (doublon, tutoiement, clé obligatoire cassante), P6 G-01/G-02 mal ciblés (forme et non sujet, textes de 012, `httptest`), P7 interaction bruit délégué/reprise, P8 découpage T12 et scénarios manquants). Tous intégrés : un seul passage (`repeatPending`, marque à usage unique, R-08), `recovery()` évaluée au refus, R-01 à R-11, G-01/G-02 réécrits, T12a/T12b. **Pour le porteur, sans bloquer** : le bruit délégué malgré la consigne reçoit « répétez » (assumé, R-09) | commit `specs/016-*` |
| 2026-10-31 | Gherkin | **Go** : `acceptance/recovery_test.go` et `recovery_helpers_test.go` (R-00 lecture du compose, R-01 à R-11), `bootstrap/voice_instructions_guard_test.go` (G-01, G-02, derrière le tag `acceptance`). Rouge pour la bonne raison : R-01 `refus après chevauchement : la voix dit "Cette demande n'est pas encore prise en charge : …", attendu la phrase no_request` ; R-05 et R-09 `out_of_catalog` dit au lieu de `no_request` ; R-00 `VOICE_RECOVERY_WINDOW absente ou non analysable dans le compose` ; G-01 `instructions vocales : aucune consigne de silence (aucune ligne ne parle de « bruit »)`. Gardes verts : R-02, R-03, R-04 hors fenêtre, R-06, R-11. `gate --unit go` vert : `.omc/state/loop/gates/20261031-134008-unit-go.log`. Contrainte pour T13 : la consigne tient en **une seule ligne** avec « bruit », « bribe », « lointaine », « intelligible », « demande d'affichage », « hors sujet », « délégu », après les lignes de délégation, fichier < 4000 caractères. À vérifier en T12 : l'antirebond ne supprime pas le second `voice.interrupted` de R-08 ; étapes suivantes de R-07/R-08 non validées avant T12 | commit Gherkin |

## Revue d'architecte
<!-- Verdict et R1…Rn ; cocher celles appliquées. -->

## Questions pour le porteur
- **Q-90** (non bloquante) : frontière bruit / demande (politesse isolée, question hors release).
