# 012 — État

- **Étape** : Gherkin
- **Tentatives** : 1/3
- **Tâche en cours** : —
- **Fichiers touchés** (tâche en cours) : —
- **Branche** : feat/012-llm-composer-crashlist
- **Backlog** : EP-03, EP-04, EP-09
- **Mis à jour** : 2026-10-30

## Journal
| Date | Étape | Fait | Preuve (journal gate.sh, capture) |
|---|---|---|---|
| 2026-10-30 | Revue du plan | architect-reviewer (Opus) : À AMENDER (3 bloquants, 4 importants, 1 mineur, 3 conflits) ; amendements A1 à A8 intégrés (`plan.md` § Amendements, `tasks.md` 28 tâches, `spec.md`, pdr-0074 D7/D8/D9) | `product_lint` |
| 2026-10-30 | Définir | spec, plan, 24 tâches, pdr-0074 (décision contrainte D1-D4, D6 ; détails D5, D7, D8) ; `product_lint` sans erreur | `python3 -I product/_tools/product_lint.py` |

## Revue d'architecte
**Revue du plan : À AMENDER → amendée.** A1 couture d'émission `emit` et critère de latence calculable (banc dans le réseau `agents`) ; A2 autorité de `ParseIntent`, `ActionBar` jamais choisie, acte 1 à quatre surfaces, `Intent.View` hors metadata ; A3 refus `view_unavailable` jusqu'à la voix (T25) ; A4 passerelle joignable des seuls agents ; A5 délais, débit, auto-test de `check-compose.sh` ; A6 paquets (`arch_test`, fabrique de composeur, `examples.json` embarqué, note Responses T19) ; A7 grille à parent unique, libellés sur deux lignes ; A8 contrat (négatives, fichiers à mettre à jour). Conflits : D7 remplacée (aucun tag), D8 voie intermédiaire signalée, pdr-0023 lue comme « sélection fermée ».

## Questions pour le porteur
Aucune bloquante. **Pour le porteur, sans bloquer** : l'appel au modèle passe par une passerelle interne de l'orchestrateur (pdr-0074 D1), car les agents n'ont ni clé ni sortie réseau ; le modèle choisit composants et paramètres, jamais les valeurs ; `COMPOSER_MODEL` vide = composition déterministe. **À brancher par le porteur** : `check-compose.sh` n'est lancé que par la CI GitHub, pas par `gate.sh`/`verify.sh` (`tools/loop/` est hors de portée de la boucle) ; l'auto-test `backend/check-compose-selftest.sh` (T24) est à ajouter à `verify.sh --full`. **D8 (squelette anticipé)** est une voie intermédiaire entre le modèle et les écrans fixes de pdr-0060 : conditionnelle, à valider si la mesure la déclenche.
