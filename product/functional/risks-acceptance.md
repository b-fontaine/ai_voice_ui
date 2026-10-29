---
id: p-fn-risks-acceptance
title: Risques, plan B, DoD et métriques
area: functional
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p11, product/sources/product-description.pdf#p12]
links: [p-rm-roadmap, p-ar-frontend, p-ar-backend, p-ar-agents-protocols, p-rm-open-questions, p-fn-nfr, p-fn-requirements, p-fn-business-rules, p-ar-stage-runtime, p-ar-replay, p-ar-quality, pdr-0006-replay-fallback-must, pdr-0010-pinned-experimental-versions, rt-echo-cancellation, rt-barge-in, proj-avw-risks, ds-a11y-wcag-contrast, pdr-0022-gherkin-steps-no-leading-digit, pdr-0023-example-guided-composition]
tags: [risques, plan-b, dod, metriques, repetition]
---
# Risques, plan B et critères d'acceptation

**En bref.** Le risque principal n'est pas technique, il est **scénique** : une démo vocale en direct sur le Wi-Fi d'une conférence. Le mode rejeu est donc une exigence **Must**, pas un bonus (fiche § 8, p. 11 ; [pdr-0006](../decisions/pdr-0006-replay-fallback-must.md)).

## Registre des risques (fiche § 8)

| # | Risque | Probabilité | Impact | Parade (fiche) | Liens | Porteur technique · jalon |
|---|---|---|---|---|---|---|
| R1 | Réseau de la salle instable | Haute | Bloquant | Connexion mobile dédiée ; mode secours en un raccourci | FR-10, NFR-07, RG-20 | [replay](../architecture/replay.md), [stage-runtime](../architecture/stage-runtime.md) · J6, J8 |
| R2 | L'IA s'entend dans la sono et se coupe elle-même | Haute | Fort | Micro-casque proche de la bouche ; voix de l'IA renvoyée dans la sono sans repasser par le micro ; test sur place | [rt-echo-cancellation], [p-ar-stage-runtime](../architecture/stage-runtime.md) | [stage-runtime](../architecture/stage-runtime.md) · SP-06, J7 |
| R3 | Interruptions intempestives (rires, applaudissements) | Moyenne | Moyen | Seuil de déclenchement réglé en répétition ; raccourci « silence » en secours | FR-18, FR-20, RG-16 | [stage-runtime](../architecture/stage-runtime.md), [agents-protocols](../architecture/agents-protocols.md) · J7 (Q-41) |
| R4 | L'IA ne s'arrête pas quand le speaker la coupe | Moyenne | Fort | Raccourci « silence » ; répliques de l'IA courtes par consigne | FR-20, RG-27, [rt-barge-in] | [agents-protocols](../architecture/agents-protocols.md) (interruption) · J7 |
| R5 | Bruit de salle et mauvaise compréhension | Moyenne | Fort | Phrases clés courtes et rodées ; transcription visible pour reformuler | FR-02 | [frontend](../architecture/frontend.md) (transcription) · J7 (script des phrases clés) |
| R6 | L'IA produit un écran incohérent | Moyenne | Fort | Catalogue restreint ; exemples d'écrans attendus fournis à l'IA ; rejeu si besoin | RG-07, [pdr-0007](../decisions/pdr-0007-closed-catalog-stage-theme.md) | [backend](../architecture/backend.md) (catalogue, exemples d'écrans : [pdr-0023](../decisions/pdr-0023-example-guided-composition.md)), [replay](../architecture/replay.md) · J3, J6 |
| R7 | Attente trop longue entre la demande et l'écran | Haute | Moyen | L'IA commente pendant la construction ; squelettes immédiats | RG-03, RG-04 | [agents-protocols](../architecture/agents-protocols.md) (commentaire), [frontend](../architecture/frontend.md) (squelettes) · J3 |
| R8 | Texte illisible au projecteur | Moyenne | Moyen | Thème de scène en 24 px minimum ; test sur un vrai projecteur | NFR-05, RG-09, [ds-a11y-wcag-contrast] | [frontend](../architecture/frontend.md) (thème de scène), [stage-runtime](../architecture/stage-runtime.md) · SP-07, J7 |

Les ids R1..R8 et la colonne « Porteur technique · jalon » sont une lecture de l'assistant ([p-rm-roadmap](../roadmap/roadmap.md)). Les risques **techniques** déjà connus sur le code voix (projet de référence) sont dans [proj-avw-risks].

## Plan B

| Niveau | Déclencheur | Action | Exigence |
|---|---|---|---|
| 1 | L'IA parle trop ou n'entend pas l'interruption | Touche « silence » (Espace, proposée) | FR-20 |
| 2 | Micro qui capte mal | Raccourci « silence » (Espace, proposée) | FR-20 |
| 3 | Écran incohérent | Rejeu si besoin (parade de la fiche § 8, R6) | FR-10 |
| 4 | Réseau perdu ou chaîne bloquée | Mode secours (B, proposée) : rejeu d'une session enregistrée, < 2 s, sans redémarrer | FR-10, NFR-07 |

⚠️ Les touches sont proposées, à valider (écart E5 · Q-05, [p-rm-open-questions](../roadmap/open-questions.md)). La gradation en niveaux est une lecture de l'assistant ; les actions reprennent les parades de la fiche § 8.

## Definition of Done de la démo (fiche § 8)

| # | Critère | Lié à |
|---|---|---|
| D1 | Les 9 scénarios de la section 4 sont vérifiés, en automatique **et** en répétition | S-01..S-09 ([features](features/)) |
| D2 | 10 répétitions complètes consécutives sans intervention manuelle, dont 2 sur réseau mobile | R1 |
| D3 | Les seuils NFR-01 à NFR-03 sont tenus au p90 sur ces 10 répétitions | [p-fn-nfr](nfr.md) |
| D4 | La bascule en mode secours est testée Wi-Fi coupé, en moins de 2 s | NFR-07 |
| D5 | La coupure de parole fonctionne 10 fois sur 10 en répétition, sono de la salle allumée, sans aucune interruption spontanée de l'IA | FR-13, R2, R3 |
| D6 | Lisibilité validée depuis le fond d'une salle réelle ou équivalente | NFR-05 |
| D7 | Build propre sur machine vierge à partir du dépôt et du `pubspec.lock` | NFR-10, [pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md) |
| D8 | Une répétition générale devant au moins 3 développeurs Flutter, avec ce test : peuvent-ils réexpliquer le rôle du catalogue en une phrase ? | Message du talk ([p-fn-vision](vision.md)) |

Mise en œuvre des mesures : [p-ar-quality](../architecture/quality.md) ; conditions de scène : [p-ar-stage-runtime](../architecture/stage-runtime.md).

## Métriques de succès du talk (fiche § 8)

| Métrique | Objectif |
|---|---|
| Taux de réussite de la démo en direct **sans rejeu** | 100 % des 3 actes |
| Nature des questions du public | Portent sur l'adoption (« comment je l'intègre ? ») plutôt que sur le fonctionnement |
| Note de feedback de la conférence | Si elle existe |

## Remarque

D1 vise « les 9 scénarios » ; plusieurs Must n'ont pas de scénario dédié (voir [p-fn-requirements](requirements.md), couverture BDD ; question Q-63). Les steps qui commençaient par un chiffre (incompatibles avec `bdd_widget_test`) sont reformulés en toutes lettres (E16 · Q-34, [pdr-0022](../decisions/pdr-0022-gherkin-steps-no-leading-digit.md)).
