---
id: ux-ai-human-in-the-loop
title: Human-in-the-loop — confirmer avant d'agir
tags: [ai-ux, human-in-the-loop, confirmation, genui, safety]
status: verified
updated: 2026-10-28
sources: [https://developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json, https://www.microsoft.com/en-us/research/wp-content/uploads/2019/01/Guidelines-for-Human-AI-Interaction-camera-ready.pdf, https://docs.flutter.dev/ai/genui/components, https://a2ui.org/specification/v0.9.1-a2ui/]
links: [ma-guardrails, ma-real-tool-results, genui-user-actions, genui-data-model, ux-ai-hax-guidelines]
---
# L'IA propose, l'utilisateur confirme les actions importantes

**Apple HIG (Generative AI) :** demander en général une confirmation avant toute action importante faite au nom de l'utilisateur. Ne pas automatiser les actions destructrices ou difficiles à annuler (supprimer des photos, faire un achat).

## Autres règles des sources
- **Apple :** placer des contrôles **Edit, Undo, Retry, Adjust** près du contenu généré.
- **Apple :** signaler clairement où et quand l'IA intervient, ne jamais faire passer une IA pour un humain, et dire que le contenu généré **peut contenir des erreurs**.
- **HAX G16 :** *Convey the consequences of user actions*. **HAX G17 :** *Provide global controls* ([[ux-ai-hax-guidelines]]).

## Ce que genui/A2UI rend possible
- Les saisies (un champ texte, par exemple) mettent directement à jour le `DataModel`. Seules les **actions** (un clic sur un bouton) créent un message vers l'agent. Une saisie ne réveille donc pas l'agent (déduit de ce contraste).
- `sendDataModel` vaut `false` par défaut dans `createSurface` : seul le contexte résolu de l'action part. À `true`, tout le modèle part dans les métadonnées des messages client vers serveur, et seulement vers le serveur qui a créé la surface.
- Chemin d'une action : [[genui-user-actions]].

## Règles recommandées (opinion)
- Toute action à effet de bord (écriture, envoi, paiement, suppression) passe par une **surface de confirmation du DS**, rendue par l'app et non composée par le LLM. Elle résume les conséquences (G16).
- L'orchestrateur exécute l'outil seulement après la confirmation, et renvoie au modèle le vrai résultat ([[ma-real-tool-results]], [[ma-guardrails]]).
- En voix, un « oui » oral ne suffit pas pour une action destructrice : la confirmation se fait à l'écran.
- Un contrôle global (pause ou désactivation de l'agent) reste accessible hors des surfaces générées (G17).

## ⚠️ Pièges
- Ne pas laisser le LLM générer lui-même le bouton « Confirmer » d'une action sensible : une injection de prompt peut produire un faux formulaire (opinion, voir genui-a2ui-security).
- « Sans appel à l'agent » pour les saisies est une déduction de la doc, pas une phrase citée.
