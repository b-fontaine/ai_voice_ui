---
id: ux-genui-errors-validation
title: Erreurs et validation dans une UI générée
tags: [genui, a2ui, validation, errors, ux]
status: verified
updated: 2026-10-28
sources: [https://a2ui.org/specification/v0.9.1-a2ui/, https://developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json, https://pair.withgoogle.com/chapter/errors-failing/]
links: [genui-error-reporting, ux-ai-human-in-the-loop, ux-genui-streaming-loading, ux-ai-trust-feedback]
---
# Deux niveaux d'erreur : la machine corrige la machine, l'humain reçoit un message clair

## Erreurs du LLM : boucle silencieuse
- Les messages de l'agent sont validés par le client **ou par le système qui agit pour lui**. La validation peut donc avoir lieu côté orchestrateur.
- En cas d'échec, un message `error` part avec le code `VALIDATION_FAILED`, le `surfaceId`, un JSON Pointer vers le champ fautif et un champ `message`. Le LLM se corrige au tour suivant (boucle prompt, generate, validate).
- Implémentation genui : [[genui-error-reporting]].

## Erreurs de saisie : `checks`
- En A2UI v0.9.1, un bouton peut définir des `checks`. Si l'un d'eux échoue, le bouton est **désactivé automatiquement**.
- Le message d'erreur précis est porté par le champ `message` de chaque check. La spec le rattache aux checks des composants d'entrée plutôt qu'au bouton.
- La spec ne dit pas comment un bouton désactivé affiche ce message.

## Erreurs visibles par l'utilisateur
- **Apple HIG :** décrire ce qui s'est passé en **langage simple** et proposer une **étape suivante** claire.
- **Google PAIR :** quand l'IA échoue, l'utilisateur doit pouvoir **reprendre la main** facilement. PAIR distingue trois types d'erreurs :
  - les limites du système ;
  - les erreurs de contexte ;
  - les erreurs « background », que ni l'utilisateur ni le système ne détectent.

## Application à une app voix + GenUI (opinion)
- L'erreur `VALIDATION_FAILED` ne s'affiche jamais : l'utilisateur voit un état de chargement, puis un message générique du DS si le plafond de corrections est atteint.
- Le message de chaque check s'affiche sous le champ, avec le composant d'erreur du DS, pas sous le bouton.
- Chaque message d'erreur propose une action : réessayer, reformuler, ou continuer à la main avec un écran non généré.
- Erreurs « background » : prévoir un signalement depuis la surface ([[ux-ai-trust-feedback]]).

## ⚠️ Pièges
- Les noms de champs exacts du message `error` (`path`, `message`) viennent d'un résumé et non d'une citation mot pour mot. Les vérifier dans la spec avant de les coder.
- **Non vérifié :** les noms des callbacks d'erreur de `Conversation` dans genui 0.10.4 (au 2026-10-27).
