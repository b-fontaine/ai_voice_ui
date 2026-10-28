---
id: ux-genui-streaming-loading
title: Streaming et états de chargement des surfaces générées
tags: [genui, a2ui, streaming, loading-states, ux]
status: verified
updated: 2026-10-27
sources: [https://a2ui.org/specification/v0.9.1-a2ui/, https://a2ui.org/concepts/data-flow/, https://pub.dev/packages/genui, https://cloudscape.design/patterns/genai/genai-loading-states/, https://cloudscape.design/patterns/genai/response-regeneration/]
links: [genui-a2ui-messages, genui-data-model, ux-genui-errors-validation, ux-voice-multimodal, rt-barge-in]
---
# Montrer l'UI qui se construit plutôt qu'un spinner

A2UI est diffusé en JSONL avec un rendu progressif : l'utilisateur voit l'interface se construire au lieu d'attendre derrière un spinner.

## Ce que permet le protocole (A2UI v0.9.1)
- Les composants arrivent en **liste plate** (liste d'adjacence liée par id), avec exactement un composant `root`.
- Le rendu peut commencer **dès que `root` est défini**. Les mises à jour reçues avant `root` sont mises en tampon.
- `updateComponents` ajoute ou met à jour des composants de façon incrémentale.
- Préférer des mises à jour **granulaires** du data model (`/user/name` plutôt que `/`).
- Côté genui, chaque morceau de texte du LLM passe par `A2uiTransportAdapter.addChunk()`, qui produit des `TextEvent` ou des `A2uiMessageEvent` pour le `SurfaceController`.

## Pattern de chargement (Cloudscape)
- **2 étapes :** *processing* (prompt envoyé, aucune sortie) puis *generation* (la sortie arrive, le traitement continue).
- Tout indicateur est accompagné d'un **texte visible** décrivant l'état.
- **Moins d'une seconde :** pas d'état de chargement (scintillement). Si le streaming démarre presque tout de suite, streamer directement.
- Streaming réservé au **texte** et au code inline. Tableaux et blocs de code : **barre de chargement**.
- Libellés : « Generating » pour un contenu nouveau, « Loading » / « Fetching » pour un contenu existant. Pas de ponctuation finale.
- Pendant la génération, le bouton d'envoi devient **Stop**. Après l'arrêt, **Regenerate** est disponible tout de suite. Regenerate remplace la réponse et **supprime les messages qui la suivaient**.

## Application au projet (opinion)
- Composant DS de chargement à deux états (traitement / génération) avec libellé localisé, réutilisé par toutes les surfaces.
- Un composant structuré (tableau, formulaire) n'apparaît qu'une fois complet ; un skeleton du DS occupe sa place en attendant.
- État de chargement porté par un Bloc dédié, alimenté par les événements de l'adaptateur via `emit.forEach`.
- En voix, Stop équivaut au barge-in ([[rt-barge-in]]).

## ⚠️ Pièges
- **Non vérifié :** aucune doc lue ne décrit d'API d'état de chargement genui (`isWaiting`, `isProcessing`…). À confirmer dans le code ou le dartdoc de genui 0.10.4 (au 2026-10-27).
- Le batching (~16 ms) et le diffing de a2ui.org n'ont été que résumés : ne pas s'en servir comme garantie.
