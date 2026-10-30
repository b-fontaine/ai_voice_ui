# 012 — État

- **Étape** : TDD
- **Tentatives** : 0/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/012-llm-composer-crashlist
- **Backlog** : EP-03, EP-04, EP-09
- **Mis à jour** : 2026-10-30

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Gherkin | T01 (agents C-01 à C-06), T02 (orchestrateur C-07, C-08), T03 (Flutter F-01, F-02). Rouges pour la bonne raison — Go : `0 appel(s) à la passerelle, attendu exactement 1` (C-01 à C-03, C-06 repli), surface `crashes` absente (C-04, C-05), écouteur de la passerelle absent (C-07), `crashes` refusé / `failure_rejected_view` absente (C-08) ; Flutter : 5 échecs sur 5, `component_not_allowed` puis `unknown_surface` (validateur client). `gate --unit` go et flutter verts. | `.omc/state/loop/gates/20261030-225637-unit-go.log`, `20261030-225625-unit-flutter.log` |
| 2026-10-30 | Revue du plan | architect-reviewer (Opus) : À AMENDER (3 bloquants, 4 importants, 1 mineur, 3 conflits) ; amendements A1 à A8 intégrés (`plan.md` § Amendements, `tasks.md` 28 tâches, `spec.md`, pdr-0074 D7/D8/D9) | `product_lint` |
| 2026-10-30 | Définir | spec, plan, 24 tâches, pdr-0074 (décision contrainte D1-D4, D6 ; détails D5, D7, D8) ; `product_lint` sans erreur | `python3 -I product/_tools/product_lint.py` |

## Revue d'architecte
**Revue du plan : À AMENDER → amendée.** A1 couture d'émission `emit` et critère de latence calculable (banc dans le réseau `agents`) ; A2 autorité de `ParseIntent`, `ActionBar` jamais choisie, acte 1 à quatre surfaces, `Intent.View` hors metadata ; A3 refus `view_unavailable` jusqu'à la voix (T25) ; A4 passerelle joignable des seuls agents ; A5 délais, débit, auto-test de `check-compose.sh` ; A6 paquets (`arch_test`, fabrique de composeur, `examples.json` embarqué, note Responses T19) ; A7 grille à parent unique, libellés sur deux lignes ; A8 contrat (négatives, fichiers à mettre à jour). Conflits : D7 remplacée (aucun tag), D8 voie intermédiaire signalée, pdr-0023 lue comme « sélection fermée ».

## Questions pour le porteur
Aucune bloquante. **Pour le porteur, sans bloquer** : l'appel au modèle passe par une passerelle interne de l'orchestrateur (pdr-0074 D1), car les agents n'ont ni clé ni sortie réseau ; le modèle choisit composants et paramètres, jamais les valeurs ; `COMPOSER_MODEL` vide = composition déterministe. **À brancher par le porteur** : `check-compose.sh` n'est lancé que par la CI GitHub, pas par `gate.sh`/`verify.sh` (`tools/loop/` est hors de portée de la boucle) ; l'auto-test `backend/check-compose-selftest.sh` (T24) est à ajouter à `verify.sh --full`. **D8 (squelette anticipé)** est une voie intermédiaire entre le modèle et les écrans fixes de pdr-0060 : conditionnelle, à valider si la mesure la déclenche.

## Hypothèses de test à respecter en production (Gherkin Go)
- Requête agent → passerelle : `POST /v1/complete` `{instructions, input, schema_name, schema}` ; réponse 200 = le plan sans enveloppe `{"surfaces":[{"component","params"}]}` ou `{"refusal":{"reason":"view_unavailable"}}` ; paramètres `platform`, `compare`, `count`.
- L'adaptateur texte lit `OPENAI_BASE_URL` (amont factice des tests) ; statuts de la passerelle : 403 source ou `Origin`, 404 chemin, 405 méthode, 413 corps trop grand, 415 type, 421 `Host`, 429 débit, 503 `disabled` ; `Host` attendu = hôte de `LLM_GATEWAY_ADDR`.
- `/crashes` : `rank`, `volume`, `sessions` numériques ; `label`, `platform` chaînes.
- Flutter : clés `crash-row-<rang>`, `crash-label-<rang>` (`maxLines: 2`, ellipse), `skeleton-crashes`, `neutral-crashes`, `surface-crashes` ; tout texte ≥ 24 px ; `crashes` déclaré surface de `CrashList` dans le contrat (T11).
