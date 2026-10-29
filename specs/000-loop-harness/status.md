# 000 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/000-loop-harness (créée 2026-10-29)
- **Backlog** : EP-01
- **Mis à jour** : 2026-10-29

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-29 | Définir | spec, plan et tâches rédigés par l'assistant lors de la préparation du dispositif | — |
| 2026-10-29 | Gherkin | T01 : H-01 à H-03 automatisés (bdd_widget_test) + coque `lib/main.dart` vide. Rouge attendu (`flutter test test/acceptance`, +0 -3) : H-01 « Found 0 widgets with key canvas-board », H-02 « Found 0 widgets with type Surface », H-03 « PNG absent ». Contrats posés : clés `canvas-board`/`voice-orb`, `Surface` genui, valeur `99,57`, `exitHandler(0)`. Titres de scénario ≤ 39 car. (format bdd_widget_test). | `.omc/state/loop/gates/20261029-132939-unit-flutter.log` (VERT) |

## Revue d'architecte

## Questions pour le porteur
