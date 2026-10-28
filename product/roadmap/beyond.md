---
id: p-rm-beyond
title: Au-delà du talk
area: roadmap
status: draft
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p2-p3, product/sources/product-description.pdf#p12, product/roadmap/backend-production-plan.md, knowledge:proto-a2a-overview]
links: [p-rm-roadmap, p-rm-open-questions, p-fn-scope, p-ar-overview, pdr-0001-conference-demo-deliverable, pdr-0004-mvp-three-acts, pdr-0009-french-only, p-rm-backend-production-plan, ma-target-architecture, proto-a2a-overview, proto-a2a-agent-card, proto-mcp-overview, genui-a2ui-v1-rc]
tags: [au-dela, hors-perimetre, evolutions, roadmap]
---
# Au-delà du talk : pistes hors périmètre MVP

**En bref.** Pistes d'évolution après J9. **Toutes sont hors périmètre du MVP** ([pdr-0001](../decisions/pdr-0001-conference-demo-deliverable.md), [pdr-0004](../decisions/pdr-0004-mvp-three-acts.md)) : aucune ne doit consommer d'effort avant le talk sans décision explicite du porteur. Chaque piste retenue fera l'objet d'un PDR via le skill `product-decide`.

| Piste | Ce que ça apporte | Ce que ça demande | Source / lien | Statut |
|---|---|---|---|---|
| **Agent tiers en A2A** | Montrer un agent d'un autre éditeur qui s'intègre sans adaptation : « l'argument le plus fort de l'approche multi-agents » | Un agent externe publiant une Agent Card ; contrat de catalogue partagé ; un acte de plus. Peut remonter dans le MVP si Q-10 est tranchée en ce sens | Fiche § 3 (question ouverte) ; [Q-10](open-questions.md) ; [proto-a2a-overview], [proto-a2a-agent-card] | Hors MVP, en attente de Q-10 |
| **Vraies sources de données** | Crashlytics, App Store Connect, Google Play Console au lieu du jeu figé | Outils MCP ou agents A2A authentifiés (OAuth, secrets côté backend) ; fin du déterminisme de NFR-08 | Fiche § 3 « Hors périmètre » ; [proto-mcp-overview], [ma-mcp-security] | Hors MVP |
| **Web et mobile** | Même démo dans un navigateur ou sur téléphone | Rendu A2UI web/mobile ; contraintes Wasm, audio et permissions par plateforme | Fiche § 3 « Mobile et web : desktop uniquement » ; [pdr-0002](../decisions/pdr-0002-desktop-platform.md) | Hors MVP |
| **Multi-utilisateur et persistance** | Plusieurs personnes sur un même tableau, historique au-delà de la session | Authentification, autorisation, stockage, tenants | Fiche § 3 « Hors périmètre » ; [p-rm-backend-production-plan](backend-production-plan.md) étapes 1, 4 | Hors MVP |
| **Autres langues** | Talk en anglais ou démo bilingue | Voix, consignes, catalogue et données localisés | Fiche § 3 ; [pdr-0009](../decisions/pdr-0009-french-only.md) | Hors MVP |
| **Ouvrir le code de la démo** | Les développeurs repartent avec un exemple GenUI + A2A complet | Retrait des dépendances internes, licence, dépôt publiable (cf. Q-27), nettoyage des secrets | [Q-27](open-questions.md) | Hors MVP, non décidé |
| **Réutilisation dans les projets Septeo** | Porter le patron voix → orchestrateur → A2UI dans les produits (successeur d'`ai_voice_widget`) | Reprise du plan backend complet : Keycloak, Kong, Temporal, MCP gateway, observabilité | [p-rm-backend-production-plan](backend-production-plan.md) étapes 9 à 12 ; [ma-target-architecture] ; `knowledge/projects/` | Hors MVP |
| **Passage à A2UI v1.0** | RPC bidirectionnel, catalogues mélangeables, `userMessage` sur les actions | Support par genui ; migration des bindings (`@path`) | [genui-a2ui-v1-rc] ; [Q-03](open-questions.md) | Hors MVP, dépend de genui |

## Règles

- Une piste ne remonte dans le MVP que par un PDR qui modifie [pdr-0004](../decisions/pdr-0004-mvp-three-acts.md).
- Les faits techniques appris en explorant une piste vont dans `knowledge/` (savoir réutilisable). Ce qui est propre à Genesis Canvas reste dans `product/`.
