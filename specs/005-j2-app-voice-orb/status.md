# 005 — État

- **Étape** : Gherkin
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/005-j2-app-voice-orb
- **Backlog** : EP-01, EP-02
- **Mis à jour** : 2026-10-29 22:34

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-29 | Gherkin | T01 faite : 4 paquets, versions exactes, DI injectable ; 1re tentative bloquée (`injectable_generator` 3.1.3 incompatible avec `build_runner` 2.16.2 / `analyzer` 14.6.0), levée par `build_runner` 2.16.1 (vérifié en copie isolée du workspace, choix contraint) ; smoke test rouge puis vert | `.omc/state/loop/gates/20261029-224730-unit-flutter.log` (VERT, 22 contrôles) |
| 2026-10-29 | Revue du plan | verdict À AMENDER (2 bloquants), A1-A8 intégrés dans spec/plan/tâches | — |
| 2026-10-29 | Définir | spec, plan, tâches rédigés (lookup product + kb faits) ; aucune Q-xx bloquante | — |

## Revue d'architecte
**Revue du plan (mode PLAN, 2026-10-29) : À AMENDER, 2 bloquants — amendements A1-A8 intégrés dans `plan.md`, `tasks.md`, `spec.md`.**
- [x] A1 bloquant — `shared` ne dépend pas d'`entities` : DTO et ports propres à `backend_channel`, `AppClock`/`A2uiDecoder` dans `shared/core`, conversion en `SessionEvent` dans `voice_session/api`
- [x] A2 bloquant — `VoiceSession` machine à états unique, Blocs minces `droppable`, fabrique de transport
- [x] A3 important — source vivante à durée de vie de la page, broadcast sans erreur, `ChannelLost`
- [x] A4 important — WSS ouvert après le 200 avec `?session=`
- [x] A5 important — `VoiceFailure` fermé, `closed` backend, WSS perdu, délai du `DELETE`
- [x] A6 important — pas de scope get_it en J2, ordre de fermeture, `onExitRequested`, modules DI dans `app/di`
- [x] A7 important — `OrbSmoother` pur, contrôleur UI, retombée, preuve NFR-04
- [x] A8 important — transcription, sockets réels dans `testWidgets`, graphe `live` seul, versions figées (T01)

## Questions pour le porteur
<!-- Q-xx créées : ce qui est bloqué, ce qui continue. -->
