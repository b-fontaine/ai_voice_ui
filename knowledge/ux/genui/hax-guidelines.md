---
id: ux-ai-hax-guidelines
title: Les 18 guidelines Human-AI Interaction (Microsoft HAX)
tags: [ai-ux, hax, guidelines, microsoft]
status: verified
updated: 2026-10-27
sources: [https://www.microsoft.com/en-us/research/wp-content/uploads/2019/01/Guidelines-for-Human-AI-Interaction-camera-ready.pdf, https://www.microsoft.com/en-us/haxtoolkit/ai-guidelines/]
links: [ux-ai-human-in-the-loop, ux-ai-trust-feedback, ux-genui-errors-validation, ux-voice-multimodal]
---
# 18 guidelines Human-AI Interaction, réparties en 4 phases

Microsoft Research (Amershi et al., CHI 2019) propose 18 guidelines. Elles ont été validées notamment par une étude où **49 praticiens du design** les ont appliquées à **20 produits** grand public intégrant de l'IA.

Le HAX Toolkit les regroupe en 4 phases : au premier contact, pendant l'interaction, quand le système se trompe, dans la durée.

| # | Intitulé exact |
|---|---|
| G1 | Make clear what the system can do |
| G2 | Make clear how well the system can do what it can do |
| G3 | Time services based on context |
| G4 | Show contextually relevant information |
| G5 | Match relevant social norms |
| G6 | Mitigate social biases |
| G7 | Support efficient invocation |
| G8 | Support efficient dismissal |
| G9 | Support efficient correction |
| G10 | Scope services when in doubt |
| G11 | Make clear why the system did what it did |
| G12 | Remember recent interactions |
| G13 | Learn from user behavior |
| G14 | Update and adapt cautiously |
| G15 | Encourage granular feedback |
| G16 | Convey the consequences of user actions |
| G17 | Provide global controls |
| G18 | Notify users about changes |

## Usage dans le projet (opinion)
- S'en servir comme grille de revue d'une surface générée ou d'un parcours vocal.
- G7, G8 et G9 couvrent l'invocation, le rejet et la correction (barge-in en voix, Stop et Regenerate à l'écran).
- G16 et G17 : voir [[ux-ai-human-in-the-loop]]. G15 : voir [[ux-ai-trust-feedback]].

## ⚠️ Pièges
- La réserve « may not be exhaustive » des auteurs porte sur la **revue de littérature** dont la liste est tirée, pas sur les guidelines elles-mêmes.
- Le découpage en phases vient du HAX Toolkit, pas du tableau ci-dessus : l'affectation de chaque guideline à une phase n'est pas reprise ici.
- Le papier date de 2019 et précède les LLM : il ne couvre ni la génération d'UI ni les hallucinations.
