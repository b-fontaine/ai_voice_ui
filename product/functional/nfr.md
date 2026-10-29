---
id: p-fn-nfr
title: Exigences non fonctionnelles NFR-01 à NFR-12
area: functional
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p6, product/sources/product-description.pdf#p7]
links: [ux-genui-streaming-loading, ux-desktop-shortcuts, genui-overview, p-fn-requirements, p-fn-business-rules, p-fn-risks-acceptance, p-ar-quality, p-ar-security, pdr-0005-frozen-fictional-dataset, pdr-0010-pinned-experimental-versions, pdr-0012-voice-provider-openai, rt-latency, ma-filler-acknowledgements, ds-a11y-wcag-contrast, perf-profile-mode-devtools, rt-ephemeral-keys, pdr-0019-six-limit-applies-to-surfaces]
tags: [nfr, latence, lisibilite, resilience, securite]
---
# Exigences non fonctionnelles (NFR-01 à NFR-12)

**En bref.** 12 exigences reprises de la fiche (§ 5, p. 6-7). Les seuils sont des **cibles de conception à valider en répétition, pas des mesures**. La façon de les mesurer est détaillée dans [p-ar-quality](../architecture/quality.md).

## Tableau

| ID | Catégorie | Exigence (fiche) | Mesure (fiche) | Repères knowledge |
|---|---|---|---|---|
| NFR-01 | Latence voix | Réponse vocale perçue en moins de 1 s après la fin de la phrase | Chronométré sur 10 répétitions, p90 | [rt-latency] |
| NFR-02 | Latence UI | Premier squelette affiché en moins de 1,5 s après la fin de la phrase | Horodatage du journal A2UI | [ux-genui-streaming-loading] |
| NFR-03 | Latence UI | Acte 1 complet en moins de 8 s | Horodatage du journal A2UI | — |
| NFR-04 | Fluidité | 60 images/s pendant les animations d'apparition | Flutter DevTools, onglet Performance | [perf-profile-mode-devtools] |
| NFR-05 | Lisibilité | Texte d'au moins 24 px, contraste WCAG AA, lisible depuis le fond de salle | Test sur vidéoprojecteur réel | [ds-a11y-wcag-contrast] |
| NFR-06 | Lisibilité | Au maximum 6 surfaces visibles en même temps | Revue visuelle | — |
| NFR-07 | Résilience | Bascule en mode secours en moins de 2 s, sans redémarrer l'app | Répétition avec Wi-Fi coupé | — |
| NFR-08 | Déterminisme | Données fictives figées ; seule la composition de l'UI varie | Snapshot des réponses d'agents | — |
| NFR-09 | Sécurité | Aucune clé OpenAI dans l'app ; jeton éphémère fourni par le backend | Revue de code | [rt-ephemeral-keys] |
| NFR-10 | Reproductibilité | Versions Flutter, genui et genui_a2a figées (pubspec.lock committé) | Build propre sur machine vierge | [genui-overview] |
| NFR-11 | Coût | Coût d'une répétition complète connu et plafonné | Tableau de bord d'usage OpenAI | — |
| NFR-12 | Accessibilité scène | Toutes les actions critiques ont un raccourci clavier | Checklist de répétition | [ux-desktop-shortcuts] |

## Décisions liées

| NFR | Décision produit |
|---|---|
| NFR-08 | [pdr-0005-frozen-fictional-dataset](../decisions/pdr-0005-frozen-fictional-dataset.md) |
| NFR-07 | [pdr-0006-replay-fallback-must](../decisions/pdr-0006-replay-fallback-must.md) |
| NFR-10 | [pdr-0010-pinned-experimental-versions](../decisions/pdr-0010-pinned-experimental-versions.md) |
| NFR-09, NFR-11 | [pdr-0012-voice-provider-openai](../decisions/pdr-0012-voice-provider-openai.md) — **proposée** |
| NFR-05 | [pdr-0007-closed-catalog-stage-theme](../decisions/pdr-0007-closed-catalog-stage-theme.md) (thème de scène) |

⚠️ **Hypothèse non confirmée.** NFR-09 (« aucune clé OpenAI ») et NFR-11 (« tableau de bord d'usage OpenAI ») supposent que le fournisseur voix est OpenAI. La fiche ne le décide pas explicitement ; la règle de projet (AGENTS.md § 2) admet aussi Gemini Live. Voir [pdr-0012](../decisions/pdr-0012-voice-provider-openai.md), Q-11 et [p-rm-open-questions](../roadmap/open-questions.md). Quel que soit le fournisseur, la règle générale reste : aucune clé longue durée côté client.

## Point délicat : NFR-01 contre NFR-02/03 (fiche § 5)

La voix répond vite (< 1 s), mais la chaîne orchestrateur → agents → A2UI prend plusieurs secondes. **L'assistant doit donc parler pendant que les surfaces se construisent** (« je lance l'analyse des crashs... »), pour que l'attente devienne du spectacle.

Traduction en règle : RG-04 ([p-fn-business-rules](business-rules.md)). Repères techniques : [ma-filler-acknowledgements] (accusés de réception sans mentir), [rt-latency].

## Lien avec la Definition of Done

La DoD ([p-fn-risks-acceptance](risks-acceptance.md)) exige que NFR-01 à NFR-03 soient tenus **au p90 sur 10 répétitions** consécutives, et que la bascule en secours (NFR-07) soit testée Wi-Fi coupé.

## Écart

NFR-06 porte sur les **surfaces** visibles. Le « n / 6 utilisés » de l'étagère des maquettes (composants du catalogue) est sans portée : E4 · Q-04 tranché par [pdr-0019](../decisions/pdr-0019-six-limit-applies-to-surfaces.md) ([p-fn-mockups](mockups.md)).
