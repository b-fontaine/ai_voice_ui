---
id: pdr-0085-replay-bar-not-covered-by-protocol-panel
title: "PDR-0085 — La barre de rejeu reste atteignable quel que soit l'état du panneau du protocole (018)"
area: decisions
status: validated
updated: 2026-11-03
sources: [product/roadmap/open-questions.md#Q-92, specs/017-design-system-v2/status.md]
links: [p-rm-open-questions, p-rm-backlog, p-rm-roadmap, pdr-0083-design-system-v2-ui-only, pdr-0084-017-design-system-ui-details-assistant-decided, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0066-010-act4-replay-details-assistant-decided, p-ar-replay]
tags: [pdr, decision, replay, protocole, mise-en-page, 018]
decision_status: acceptée
decided_on: 2026-11-03
decided_by: "Benoît FONTAINE (porteur), conversation Claude Code"
scope: fonctionnel
supersedes: []
superseded_by: null
---
# PDR-0085 — La barre de rejeu reste atteignable quel que soit l'état du panneau du protocole (018)

> **En bref.** Le porteur confie à la boucle la correction de [Q-92](../roadmap/open-questions.md) (a) : la barre de rejeu (toutes ses commandes) doit rester atteignable et visible, panneau du protocole déplié ou replié, à 1920×1080. La solution de mise en page est laissée à la boucle (pdr-0062).

Part de l'assistant : il a recommandé de corriger maintenant ; le porteur a décidé.

## Contexte
Q-92 (a) : le panneau du protocole déplié (x 1116..1896, y 452..1072) recouvre 304 px des 480 px de la barre de rejeu (x 940..1420). Recommencer, glissière, « Direct » et vitesses sont inatteignables ; le test R-01 ne passe que par un contournement de 017 (centre de Lecture à 3,2 px du bord). Le recouvrement préexiste à 017. Risque : bloquer l'acte 4 sur scène.

## Hypothèses
- ✅ Le bug peut bloquer l'acte 4 sur scène (Q-92 a ; [p-ar-replay](../architecture/replay.md)).

## Options
1. **Corriger par la boucle maintenant (018)** (retenue).
2. Replier le panneau avant de rejouer, en attendant la répétition (Q-92 a, option 1).

## Décision
- La barre de rejeu, avec toutes ses commandes (Lecture, Recommencer, glissière, « Direct », vitesses), reste visible et atteignable quel que soit l'état du panneau du protocole (déplié ou replié), à 1920×1080, sans marge de contournement.
- La solution de mise en page est laissée à la boucle (détail d'interface, pdr-0062). Le comportement du rejeu et du panneau ne change pas au-delà de ce que la correction exige.
- Q-92 reste ouverte pour (b), (c), (d) et (e) ; (a) est tranchée → ce PDR.

## Raisons
- Risque de blocage sur scène à l'acte 4, constaté sur capture.
- Le contournement de 017 est fragile (3,2 px).

## Options écartées
- Replier le panneau avant de rejouer : dépend d'un geste du présentateur en direct.

## Conséquences
- Fonctionnalité **018** inscrite au [backlog](../roadmap/backlog.md) et à `specs/progress.md`.
- Preuves attendues : test d'acceptation par commande, panneau déplié et replié ; capture `app-smoke` 1920×1080 ; `gate --full` vert.

## Réexaminer si
- La mise en page retenue masque une information du protocole utile à l'acte 1.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-03 | Acceptée. Proposition de l'assistant : « Je te conseille de faire corriger Q-92 (a) par la boucle maintenant plutôt que d'attendre la répétition : ce bug peut bloquer l'acte 4 sur scène. Veux-tu que je la lui confie ? ». Réponse du porteur : « oui, confie-le à la boucle » (conversation Claude Code, 2026-11-03). | Benoît FONTAINE (porteur) |

Pas d'archive brute.
