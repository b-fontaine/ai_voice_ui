---
id: pdr-0002-desktop-platform
title: "PDR-0002 — Flutter desktop, macOS prioritaire, Windows en secours, projection 1920×1080"
area: decisions
status: validated
updated: 2026-10-28
sources: [product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p3, knowledge:genui-overview, knowledge:rt-provider-abstraction, knowledge:ux-desktop-shortcuts, knowledge:ds-widgetbook-4-spike]
links: [p-fn-scope, p-fn-screen, p-fn-nfr, p-ar-frontend, p-ar-stage-runtime, p-ar-stack, p-rm-spikes, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0012-voice-provider-openai, adr-0001-initial-constraints, adr-0004-ds-visual-base-m3, genui-overview, rt-provider-abstraction, ux-desktop-shortcuts, ds-widgetbook-4-spike]
tags: [pdr, decision, platform, desktop, macos, windows]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0002 — Plateforme : Flutter desktop

> **En bref.** L'app tourne en Flutter desktop, sur macOS en priorité et Windows en secours, et elle est projetée en 1920×1080. Mobile et web sont hors périmètre. L'OS de la machine de démo n'est pas encore confirmé, et le secours Windows doit être vérifié pour genui et la voix.

Part de l'assistant : mise en forme ; les risques de plateforme viennent de la base knowledge.

## Contexte
- Fiche § 1 (p. 1) : « Flutter desktop (macOS prioritaire, Windows en secours), projeté en 1920×1080 ».
- Fiche § 3 « Hors périmètre » (p. 3) : « Mobile et web : desktop uniquement ».
- Côté knowledge, [adr-0001-initial-constraints] mentionnait des exigences web, mobile et desktop, et [adr-0004-ds-visual-base-m3] une cible desktop et web. Ces ADR sont génériques : le produit restreint la cible au desktop.

## Hypothèses
- ✅ Projection en 16:9, 1920×1080 (fiche § 1 et § 6).
- ⚠️ Hypothèse non confirmée : OS de la machine de démo (fiche § 1 : « l'OS de la machine de démo […] n'[est] pas fixé ») → [p-rm-open-questions](../roadmap/open-questions.md) (Q-07).
- ⚠️ Hypothèse non confirmée : `genui` fonctionne sous Windows. pub.dev ne détecte qu'Android, iOS, macOS et web pour `genui` 0.10.4 [genui-overview] → à vérifier par spike ([p-rm-spikes](../roadmap/spikes.md)) ; Q-45 dans [p-rm-open-questions](../roadmap/open-questions.md).
- ⚠️ Hypothèse non confirmée : la chaîne voix tourne sur la plateforme de secours. `firebase_ai` n'a ni Windows ni Linux [rt-provider-abstraction] ; impact selon [pdr-0012-voice-provider-openai](pdr-0012-voice-provider-openai.md).

## Options
1. **Flutter desktop** (retenue).
2. Mobile.
3. Web.

## Décision
- Cible unique : Flutter **desktop**. macOS est la plateforme principale, Windows la plateforme de secours.
- Mise en page pensée pour un écran projeté **1920×1080** (16:9).

## Raisons
- La fiche ne détaille pas les raisons du choix. Lecture de l'assistant, à confirmer : un écran large est nécessaire pour les 6 zones simultanées ([pdr-0008-single-screen-show-the-making](pdr-0008-single-screen-show-the-making.md)) et la régie clavier (NFR-12).

## Options écartées
- **Mobile et web** : hors périmètre explicite, fiche § 3 (p. 3). Aucune raison détaillée dans la source.

## Conséquences
- **Fonctionnel** : régie au clavier physique (raccourcis de [p-fn-screen](../functional/screen.md)) ; lisibilité au projecteur (NFR-05).
- **Architecture** : [p-ar-frontend](../architecture/frontend.md) cible macOS puis Windows. Raccourcis via `Shortcuts`/`Actions` [ux-desktop-shortcuts] ; ces raccourcis ne se déclenchent que si le sous-arbre a le focus, point à traiter pour la régie de scène.
- **Écart à signaler** : les raccourcis proposés par la fiche sont des touches seules (Espace, M, P, R, B), alors que [adr-0004-ds-visual-base-m3] et [ux-desktop-shortcuts] suivent les conventions Cmd/Ctrl. Les raccourcis restent « à valider » (fiche § 6) → [p-rm-open-questions](../roadmap/open-questions.md) (Q-05).
- **Qualité** : le spike Widgetbook a été validé sous Linux et Chrome, pas sous macOS ni Windows [ds-widgetbook-4-spike]. Un build propre sur machine vierge est requis sur l'OS retenu (NFR-10).
- **Roadmap** : spike « genui + voix sur macOS et Windows » à planifier tôt ([p-rm-spikes](../roadmap/spikes.md)) ; machine de démo et machine de secours dans [p-ar-stage-runtime](../architecture/stage-runtime.md).

## Réexaminer si
- La machine de démo confirmée n'est ni macOS ni Windows.
- Le spike montre que `genui`, `genui_a2a` ou la chaîne WebRTC ne fonctionnent pas sous Windows : le secours devient une deuxième machine macOS ou le seul mode rejeu.
- Le talk se tient sur un format qui impose une autre résolution de projection.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 1, § 3) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR, risques de plateforme ajoutés depuis knowledge | Assistant (mise en forme) |

Pas d'archive brute.
