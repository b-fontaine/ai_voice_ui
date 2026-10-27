---
id: test-pyramid-flutter
title: Pyramide de tests Flutter — unit, widget, integration
tags: [strategy, unit, widgets, integration]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/testing/overview]
links: [test-tdd-red-green-refactor, test-integration-test, test-patrol, test-golden-alchemist]
---
# Beaucoup de tests unitaires et de widgets, peu d'intégration

La doc Flutter (consultée le 2026-10-26 ; page mise à jour le 2026-05-05, Flutter 3.47) recommande « beaucoup de tests unitaires et de widgets, et assez de tests d'intégration pour couvrir les cas d'usage importants ».

| | Unit | Widget | Integration |
|---|---|---|---|
| Confiance | faible | plus haute | maximale |
| Coût de maintenance | faible | plus haut | maximal |
| Dépendances | peu | plus | le plus |
| Vitesse | rapide | rapide | lente |

## Répartition proposée (opinion)
- **Unit (`test/`) :**
  - orchestrateur, parseurs d'événements realtime (OpenAI et Gemini)
  - mapping vers A2UI, BLoC/Cubit
- **Widget (`test/`) :**
  - écrans
  - rendu des surfaces GenUI à partir d'un message A2UI figé
  - scénarios BDD (`bdd_widget_test`)
  - goldens (alchemist)
- **Integration (`integration_test/` ou `patrol_test/`) :**
  - quelques parcours bout en bout sur device
  - permission micro, session vocale réelle contre un backend de test

## ⚠️ Pièges
- Une session voix réelle dans un test d'intégration est lente et instable (réseau, quota). Opinion : réserver ces tests à un job CI nocturne et les taguer (`@Tags(['e2e'])`).
