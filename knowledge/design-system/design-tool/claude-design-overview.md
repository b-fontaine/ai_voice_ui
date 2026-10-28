---
id: ds-claude-design-overview
title: Claude Design — produit, plans, fermeture du site autonome, exports
tags: [claude-design, design-tool, anthropic, handoff, design-system]
status: verified
updated: 2026-10-28
sources: [https://www.anthropic.com/news/claude-design-anthropic-labs, https://support.claude.com/en/articles/14604416-get-started-with-claude-design, https://claude.com/product/design, https://support.claude.com/en/articles/17440474-move-from-standalone-claude-design-to-claude, https://support.claude.com/en/articles/14604406-claude-design-admin-guide-for-team-and-enterprise-plans, https://claude.com/blog/claude-design-stays-on-brand-for-daily-work, https://code.claude.com/docs/en/artifacts.md, https://code.claude.com/docs/en/changelog.md]
links: [adr-0007-ds-design-tool-claude-design, ds-claude-design-tokens, ds-claude-design-workflow]
---
# Claude Design, outil de design d'Anthropic, vit désormais dans Claude (artifacts)

Annoncé le 2026-04-17, Claude Design est un produit **Anthropic Labs** en *research preview*, propulsé par Claude Opus 4.7. Il produit designs, prototypes, slides et one-pagers. Retenu comme outil de design par [[adr-0007-ds-design-tool-claude-design]].

## Plans (état au 2026-10-28)
- Au lancement (avril 2026) : Pro, Max, Team et Enterprise seulement ; désactivé par défaut sur Enterprise. Situation dépassée.
- Aujourd'hui, selon le centre d'aide : Free, Pro, Max, Team et Enterprise, activé par défaut. Sur Enterprise, l'activation par défaut date du 2026-10-15 ; avant, un Owner pouvait l'activer dans Organization settings > Artifacts.
- La page produit inclut Claude Design, Claude Slides et Claude Docs dans tous les plans, Free compris.

## Fin du site autonome : « Claude Design now lives in Claude »
- `claude.ai/design` ferme le **2026-12-14**. Il reste accessible jusque-là, puis passe en lecture seule (plus de création de projet).
- Un nouveau design, design system ou deck démarré dans Claude devient un **artifact claude.ai**, pas un projet du site autonome.
- Migration : « Move team design systems » (page Artifacts) déplace tous les design systems de l'organisation ; un owner peut aussi en déplacer un seul. Chats et commentaires ne migrent pas. Les liens publics des projets autonomes cesseront de fonctionner.
- Claude Code v2.1.302 (2026-10-16) affiche cet avis de fermeture dans `/design-sync` et `/design-login`.

## Exports et handoff
- Menu « Export » : PDF, PPTX, Google Slides, HTML autonome, « Download as .zip », et envoi vers une quinzaine d'apps tierces (Canva, Miro, Vercel…). Le guide admin cite bundles HTML, PPTX, PDF, Google Slides et le handoff Claude Code.
- Billet du 2026-06-17 : exports PDF/PowerPoint/HTML, apps connectées (Canva, Gamma, Vercel, puis Adobe, Base44, Lovable, Miro, Replit, Wix), rôle admin qui approuve un design system standard et en verrouille l'édition.
- **Handoff** vers Claude Code : « Send to local coding agent » ou « Send to Claude Code Web ».
- Dans Claude Code (v2.1.265+), `/design <brief>` publie un canevas d'artboards éditables (artifact Claude Design), édité dans un navigateur desktop ; chaque artboard s'exporte en PNG ou PDF. Sur Enterprise, un Owner doit activer le template Design (bêta).

## ⚠️ Pièges
- Non vérifié : le contenu exact du bundle de handoff (HTML/CSS/JS ? React ?).
- Non vérifié mot à mot : l'export .zip et la liste exacte des apps partenaires ; les sources divergent.
- Non vérifié : un export Figma. L'import de « Figma files » est cité sans mécanisme décrit.
- Produit en preview : revérifier plans et dates avant toute affirmation publique (opinion).
