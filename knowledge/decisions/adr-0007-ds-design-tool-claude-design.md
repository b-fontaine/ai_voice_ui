---
id: adr-0007-ds-design-tool-claude-design
title: "ADR-0007 — Outil de design : Claude Design"
tags: [adr, decision, design-system, claude-design, design-tokens]
status: opinion
updated: 2026-10-28
sources: [https://support.claude.com/en/articles/17440474-move-from-standalone-claude-design-to-claude, https://claude.com/product/design]
links: [ds-claude-design-overview, ds-claude-design-tokens, ds-claude-design-workflow, adr-0005-ds-tokens-style-dictionary, ds-tokens-figma-sources]
---
# ADR-0007 — Claude Design comme outil de design, le DTCG du dépôt restant la source de vérité

- **Statut :** acceptée le 2026-10-28.
- **Décideur :** le porteur du projet a choisi « Claude Design ». L'assistant avait laissé ce point ouvert, faute de connaître l'outil de l'équipe.
- **Portée :** générique, avec contexte d'origine propre au projet (voir « Contexte d'origine (non générique) »).

## Contexte d'origine (non générique)
Le choix réutilisable est « Claude Design pour maquettes et prototypes, DTCG du dépôt comme source de vérité ». Sont propres au projet d'origine : « slides du talk » (Décision) et « cohérent pour un talk » (Raisons).

## Contexte (vérifié le 2026-10-28)
- Claude Design (Anthropic Labs, annoncé le 2026-04-17) produit des designs, des prototypes, des slides et des design systems.
- Le site autonome claude.ai/design **ferme le 2026-12-14**. Les nouveaux designs et design systems deviennent des **artifacts dans Claude** [[ds-claude-design-overview]].
- Le rendu est **web uniquement** (HTML, avec React en option). Aucune source ne mentionne Flutter. `/design-sync` ne synchronise que des bibliothèques React.
- Les tokens d'un design system Claude Design sont stockés dans un `tokens.json` **propriétaire**, au format liste, qui n'est **pas du DTCG** [[ds-claude-design-tokens]].

## Décision
- **Claude Design** sert aux maquettes, aux prototypes d'écrans et de surfaces GenUI, et aux slides du talk.
- La source de vérité des tokens reste les fichiers DTCG du dépôt ([[adr-0005-ds-tokens-style-dictionary]]). Style Dictionary génère deux sorties : le **Dart** (ThemeData et ThemeExtension) et le **`tokens.json` Claude Design**, qui alimente le design system artifact.
- L'implémentation reste en **widgets `Ds*` Flutter**, vérifiés dans Widgetbook. Le handoff Claude Design → Claude Code sert de spécification, pas de code à reprendre tel quel [[ds-claude-design-workflow]].
- On n'utilise pas Figma ([[ds-tokens-figma-sources]] reste une note de référence), ni `/design-sync`, qui ne fonctionne qu'avec React.

## Raisons
- Choix du porteur. C'est aussi cohérent pour un talk : tout l'outillage IA vient du même écosystème.
- Comme Claude Design n'exporte ni Flutter ni DTCG, garder le DTCG dans Git évite d'enfermer les tokens dans un format propriétaire.

## Hypothèses
- **Sens de synchronisation : code → design** (DTCG → `tokens.json`). Les ajustements faits dans Claude Design sont reportés à la main dans le DTCG. **Confirmé par le porteur le 2026-10-28.**
- Aucun export DTCG officiel ni téléchargement direct de `tokens.json` n'est documenté. La conversion se fait côté dépôt.
- Le sort de `/design-sync` après le 2026-12-14 n'est pas connu (sans impact ici).

## Quand réexaminer
- Claude Design ajoute un export DTCG ou Flutter.
- Le format `tokens.json` change, puisque l'outil est en research preview.

## Historique
- 2026-10-28 — portée précisée lors du nettoyage de knowledge/ (porteur).
