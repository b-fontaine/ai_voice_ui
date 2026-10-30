---
id: pdr-0066-010-act4-replay-details-assistant-decided
title: "PDR-0066 — Acte 4 (J6) : journal client en mémoire, rejeu par le même gate, vitesses discrètes, gaps plafonnés"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/010-j6-act4-replay/spec.md, specs/010-j6-act4-replay/plan.md, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p4]
links: [p-rm-open-questions, p-fn-screen, p-fn-business-rules, p-fn-requirements, p-ar-replay, p-ar-frontend-screen, pdr-0032-obs-video-fallback-a2ui-replay-act, pdr-0033-optional-shortcuts-mouse-first, pdr-0038-latency-measured-on-app-clock, pdr-0053-client-side-a2ui-validation-from-007, pdr-0054-stage-screen-orb-acts-checklist, pdr-0059-acts-2-3-and-replay-simplifications, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0065-009-act3-interact-details-assistant-decided, genui-a2ui-messages, genui-multiple-surfaces]
tags: [pdr, decision, acte-4, rejeu, fr-09]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0066 — Acte 4 (J6) : détails du rejeu

> **En bref.** La fiche et pdr-0032 fixent le résultat (flux A2UI seul enregistré, rejeu de 0,25× à 2×, sans réseau ni LLM, synchronisé avec le panneau du protocole). Elles sont muettes sur le mécanisme et sur le détail des commandes ; la boucle tranche huit détails sous la règle permanente pdr-0062 et les signale au porteur, qui peut les contester. Aucun ne touche le périmètre, la mise en scène des actes, le budget ni les fournisseurs.

Part de l'assistant : décision prise sur délégation (pdr-0062), contestable par le porteur.

## Contexte
- [pdr-0032](pdr-0032-obs-video-fallback-a2ui-replay-act.md) : enregistrement du flux A2UI seul, rejeu 0,25×–2×, acte 4 ; [pdr-0059](pdr-0059-acts-2-3-and-replay-simplifications.md) : pas de pas-à-pas ←/→ ; [pdr-0033](pdr-0033-optional-shortcuts-mouse-first.md) : souris d'abord.
- [p-ar-replay](../architecture/replay.md) (`draft`) : journal JSONL, horloge virtuelle, seek par remise à vide puis réinjection.
- Existant (000, 007) : `A2uiReplaySource` (JSONL `{t_ms, message}`), `A2uiGate` (validateur à état, flux unique), panneau du protocole et étagère branchés sur le flux validé, zone « REJEU » inactive.

## Hypothèses
- ✅ Le validateur A2UI est déterministe : rejouer les mêmes messages bruts dans un validateur remis à zéro redonne les mêmes verdicts, donc le même canevas (007, parité Go/Dart).
- ✅ genui 0.10.4 accepte qu'une surface supprimée soit recréée avec le même identifiant (la remise à vide de 007 le fait déjà).

## Options
1. Journal en mémoire côté client, rejeu **par le même gate** (retenue).
2. Rejeu direct dans le `CanvasBloc`, sans validateur : écarté, le panneau et l'étagère ne suivraient pas.
3. Journal écrit sur disque pendant la session : écarté, la fiche exclut la persistance (§ 3, pdr-0032).

## Décision
| Id | Décision |
|---|---|
| **D1** | **Journal client en mémoire**, une entrée par événement `A2uiEnvelopeReceived` du flux vivant : `seq`, `t_ms` (horloge de l'app, pdr-0038, depuis le premier message), JSON **brut** tel que reçu, `agent`, `task`. Les messages refusés ou ignorés y sont aussi (le validateur rejoué redonne les mêmes verdicts). Aucun fichier, aucune voix, aucune transcription, aucune action. Il est vidé par la remise à vide de la scène (nouvelle session de démo).  Aucune sérialisation du journal (amendement A7 de la revue du plan : aucun usage, la fiche § 3 exclut la persistance) ; le message décodé n'est pas conservé, il est redécodé depuis le JSON brut à chaque injection. |
| **D2** | **Le rejeu repasse par le même `A2uiGate`** (validateur remis à zéro, même instance) : canevas, panneau du protocole (message rejoué mis en évidence, contour pointillé de sa surface) et étagère se reconstruisent donc d'un seul flux, comme en direct. |
| **D3** | **Entrée et sortie.** « Lecture » entre en rejeu s'il y a un journal et qu'aucun agent n'est occupé : le canevas est vidé (sans appel au backend), le flux vivant n'alimente plus le gate, le journal ne s'enrichit plus, les actions du canevas et « Démarrer » sont inactifs, l'indicateur d'acte affiche « Acte 4 · Rejeu » (non cliquable). La session voix en cours n'est pas touchée (pdr-0032). « Direct » quitte le rejeu par la remise à vide complète de la scène (backend compris) ; le journal est alors vidé. |
| **D4** | **Commandes** : Lecture/Pause, Recommencer, curseur de position sur l'historique, cinq vitesses discrètes 0,25× · 0,5× · 1× · 1,5× · 2×, « Direct ». Pas de pas-à-pas ←/→ (pdr-0059), aucun raccourci (pdr-0033). Changer de vitesse en cours de lecture ne saute pas : la position continue à la nouvelle vitesse. |
| **D5** | **Positionnement** : déplacer le curseur (avant comme arrière) remet le canevas à vide puis réinjecte instantanément les messages jusqu'à la position (genui est incrémental), puis la lecture reprend si elle était en cours. À la fin du journal, le rejeu s'arrête sur la dernière image ; « Lecture » repart de zéro. |
| **D6** | **Écarts plafonnés** : l'attente virtuelle entre deux messages consécutifs est plafonnée à `replayMaxGap` (réglage injecté, 3 s par défaut, valeur à 1×), pour que les silences d'un speaker qui parle entre deux actes ne vident le rejeu ; l'axe du curseur est cet axe comprimé. Dans une rafale de génération, aucun écart n'atteint 3 s : le rythme est celui du direct. |
| **D7** | **Étendue** : le rejeu couvre tout le journal de la session (actes 1 à 3), qui commence par l'acte 1 que la fiche dit « repasser au ralenti » ; le speaker arrête ou déplace le curseur où il veut. Aucun marqueur d'acte n'est enregistré en J6 (les marqueurs de mesure de [p-ar-replay](../architecture/replay.md) servent NFR-02/03, J8). |
| **D8** | **Compléments de la revue du plan.** « Remettre à vide » pendant un rejeu équivaut à « Direct » ; « Direct » reste toujours actif. « Lecture » est inactif sans journal, pendant qu'un agent travaille, pendant une action en cours. Les messages vivants écartés en rejeu sont comptés et un seul message (le nombre) est écrit à la sortie. Le panneau du protocole reste déplié pendant un curseur ou un « Recommencer » et affiche l'heure du rejeu (pas celle du direct). La zone Rejeu passe à 480 px de large sur deux rangées de 48 px (l'étagère de 1040 à 900 px). Le curseur n'applique qu'un seul positionnement par glissement. |

## Raisons
- Fiche suivie (pdr-0017) : « l'acte 1 repasse au ralenti, synchronisé avec le JSON ».
- Un seul chemin de validation (D2) garantit « identique au direct » sans second moteur et réutilise 007.
- D6 : sans plafond, un rejeu d'une démo de dix minutes en contiendrait plusieurs de silence à 1× et serait inutilisable en salle ; à 0,25× la vitesse reste maîtrisée par le speaker.

## Options écartées
- Écriture du journal sur disque pendant la session (fiche § 3) ; marqueurs d'acte et pas-à-pas (pdr-0059) ; vitesse en curseur continu (cinq paliers lisibles à distance, cible tactile ≥ 24 px) ; rejeu de la voix (Q-18, pdr-0032).

## Conséquences
- [p-ar-replay](../architecture/replay.md) : format du journal (D1), états Direct/Rejeu, plafond d'écart (D6) ; [p-fn-screen](../functional/screen.md) : zone Rejeu active, indicateur « Acte 4 · Rejeu » ; [p-fn-business-rules](../functional/business-rules.md) RG-19 ; [p-rm-backlog](../roadmap/backlog.md) EP-07 et EP-05 (synchronisation du panneau) livrés ; [p-rm-roadmap](../roadmap/roadmap.md) J6.

## Réexaminer si
- Le porteur veut un rejeu limité à l'acte 1, des marqueurs d'acte sur le curseur ou un plafond d'écart différent ; la répétition montre qu'un silence plafonné à 3 s est encore trop long.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Texte de D1 aligné sur la revue du plan (A7, pas de sérialisation) et sur la revue du code (R1, redécodage à chaque injection). | Assistant (boucle) |
| 2026-10-30 | Acceptée sur délégation (pdr-0062) : la fiche et pdr-0032 sont muettes sur le mécanisme du rejeu et sur ses commandes ; signalée au porteur dans `specs/progress.md`. | Assistant (boucle) |

Pas d'archive brute.
