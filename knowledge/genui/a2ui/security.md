---
id: genui-a2ui-security
title: Sécurité A2UI — le catalogue comme liste blanche et frontière de sécurité
tags: [a2ui, security, catalog, prompt-injection, multi-agent, genui]
status: verified
updated: 2026-10-26
sources: [https://a2ui.org/, https://github.com/google/A2UI, https://a2ui.org/guides/defining-your-own-catalog/, https://github.com/a2ui-project/a2ui/blob/main/docs/public/concepts/catalogs.md, https://github.com/a2ui-project/a2ui/blob/main/docs/public/concepts/transports.md, https://pub.dev/packages/genui]
links: [genui-catalog-ids, genui-custom-catalog-item, genui-a2ui-overview, genui-a2ui-transports, genui-migration-from-0-7, ma-prompt-injection-tools, ma-guardrails, ma-target-architecture, proto-a2ui-pointer, proj-avw-genui-bridge, proj-avw-risks]
---
# A2UI transporte des données déclaratives : l'agent ne peut demander que des composants du catalogue client

a2ui.org : « Secure by Design » — « Declarative data format, not executable code. Agents can only use pre-approved components from your catalog—no UI injection attacks. » Garanties **revendiquées par le projet lui-même** ; aucun audit indépendant trouvé.

**Mécanisme :** un catalogue est un schéma JSON (composants, fonctions, thèmes autorisés) ; tout JSON A2UI de l'agent est validé contre le catalogue choisi. Négociation : le client envoie `supportedCatalogIds` (ordre de préférence) dans **chaque** message ; l'agent choisit à `createSurface`, choix figé pour la vie de la surface ; aucun catalogue compatible → pas d'UI ([[genui-catalog-ids]]).

## Recommandations officielles (guide « Defining your own catalog »)
1. **Liste blanche :** n'enregistrer que des composants de confiance. Pas de capacité dangereuse (script, webview libre) sans contrôle strict.
2. **Valider les propriétés** contre les contraintes de type (genui valide contre le schéma du catalogue).
3. **Assainir le texte** fourni par l'agent avant de le rendre.

## Règles internes (opinion)
- Un catalogue **métier** restreint en prod (pas le catalogue de base complet), versionné par URI.
- Valider **deux fois** : dans l'orchestrateur avant envoi (rejet + nouvelle génération), puis dans le client au rendu.
- `openUrl` est dans le catalogue de base : filtrer schémas (`https` seulement) et domaines via un `ActionDelegate`, ou retirer la fonction.
- `Image`/`Video` chargent des URLs du LLM : restreindre aux domaines connus. Markdown : désactiver ou confirmer les liens.
- Les actions utilisateur sont des **événements typés** renvoyés à l'orchestrateur, jamais exécutées directement. Toute action sensible (paiement, suppression) est confirmée hors GenUI : l'injection de prompt en amont reste possible (faux formulaire, [[ma-prompt-injection-tools]]).
- Ne jamais mettre de secret dans le data model : avec `sendDataModel`, il repart vers l'agent. Le texte tiers lié s'affiche comme texte, jamais interprété.

## ⚠️ Pièges
- Le README de `genui` 0.10.4 montre encore `CoreCatalogItems.asCatalog()`, absent du code : utiliser `BasicCatalogItems`. Les API de [[proj-avw-genui-bridge]] (`GenUiConversation`, `A2uiMessageProcessor`) sont anciennes ([[genui-migration-from-0-7]]).
