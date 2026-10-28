---
id: ux-ai-trust-feedback
title: Confiance calibrée, sources et feedback
tags: [ai-ux, trust, feedback, citations, explainability]
status: sourced
updated: 2026-10-28
sources: [https://pair.withgoogle.com/chapter/explainability-trust/, https://pair.withgoogle.com/chapter/feedback-controls/, https://www.nngroup.com/articles/explainable-ai/, https://cloudscape.design/patterns/genai/generative-AI-chat/, https://developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json]
links: [ux-ai-hax-guidelines, ux-ai-human-in-the-loop, ux-genui-errors-validation, ma-real-tool-results]
---
# Viser une confiance calibrée, pas aveugle

**Google PAIR (Explainability & Trust)** vise une confiance calibrée. Il juge risqués les **indicateurs de confiance numériques**. Avec des catégories de confiance, il faut indiquer clairement l'action à mener pour chaque catégorie.

## Sources et explications
- **Cloudscape :** citer les sources inline avec des numéros `[1]`, `[2]`, `[3]` dans l'ordre, ou les lister dans une section dépliable intitulée « Sources ».
- **NN/g (source secondaire, article du 2025-12-12) :** des citations peuvent donner une impression de fiabilité quelle que soit leur validité. NN/g déconseille aussi :
  - les explications pas-à-pas qui suggèrent une certitude ou une transparence ;
  - le langage anthropomorphique, au profit d'un langage factuel et neutre.

## Feedback
- **Cloudscape :** boutons « Helpful » / « Not helpful » sous une réponse. Le feedback complémentaire est facultatif.
- **Apple HIG :** le feedback reste toujours **volontaire**. Les pouces haut/bas sont une suggestion (« Consider offering »).
- **PAIR (Feedback & Control) :** il distingue le feedback **implicite** (*product logs*) et le feedback **explicite**. Il faut pouvoir refuser certains aspects du partage implicite, et pouvoir adapter, éditer ou désactiver la sortie de l'IA.

## Application à une app voix + GenUI (opinion)
- Pas de pourcentage de confiance dans les surfaces générées. Si un niveau est utile, le montrer sous forme de catégorie avec l'action attendue (« à vérifier »).
- Une citation n'est affichée que si elle provient d'un vrai résultat d'outil ([[ma-real-tool-results]]), jamais d'un texte du LLM.
- Un composant DS de feedback (Helpful / Not helpful + commentaire facultatif) est attaché à chaque surface, sans bloquer le flux.
- L'agent vocal parle de façon factuelle, sans « je pense » ni « je ressens ».
- Le consentement au feedback implicite est un réglage explicite de l'app.

## ⚠️ Pièges
- NN/g est une source secondaire : le cas « citation hors sujet » est une légère extrapolation de « regardless of its validity ».
- Aucun article NN/g sur les agents IA n'a été lu.
