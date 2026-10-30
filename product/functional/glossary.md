---
id: p-fn-glossary
title: Glossaire
area: functional
status: draft
updated: 2026-10-30
sources: [product/sources/product-description.pdf, product/sources/design-example.pdf, knowledge:genui-a2ui-overview, knowledge:rt-barge-in]
links: [p-fn-screen, p-fn-catalog, p-fn-business-rules, p-fn-mockups, genui-a2ui-overview, genui-overview, genui-multiple-surfaces, genui-data-model, genui-catalog-ids, genui-a2a-connector, rt-barge-in, rt-echo-cancellation, rt-ephemeral-keys, ma-target-architecture, pdr-0013-orchestrator-visible-agent-selection, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0032-obs-video-fallback-a2ui-replay-act]
tags: [glossaire, vocabulaire]
---
# Glossaire

**En bref.** Le vocabulaire commun du produit, fonctionnel et technique. Quand un terme a deux noms (fiche / maquettes), les deux sont donnés. Les définitions techniques renvoient à la note `knowledge/` qui fait foi.

## Produit et scène

| Terme | Définition | Source |
|---|---|---|
| **Genesis Canvas** | Nom du produit : l'application Flutter desktop projetée en conférence. | Fiche § 1 |
| **Release Copilot** | Cas d'usage métier : préparer la décision go/no-go d'une release mobile. | Fiche § 1 |
| **Speaker** | Benoît, qui donne le talk et pilote la démo (voix, clic, clavier). | Fiche § 2 |
| **Acte** | Étape du déroulé : 1 Créer, 2 Transformer, 3 Interagir, 4 Rejouer (optionnel). | Fiche § 2 ; voir aussi « étape » |
| **Étape (maquettes)** | Indicateur « n / 3 » des maquettes : Vide, Construction, Transformation. Ne coïncide pas avec les actes (E9 · Q-22 → pdr-0054 : l'indicateur « Acte n/3 » suit les 3 actes de la fiche). | Maquettes 1-3 |
| **Go/no-go** | Décision de publier ou de bloquer une release, fondée sur des critères et leurs seuils. | Fiche § 1, § 7 ; maquette 3 |
| **Seuil go** | Valeur minimale ou maximale qu'un critère doit respecter (ex. sans crash ≥ 99,50 %). | Maquette 3 |
| **Thème de scène** | Thème visuel unique (couleurs, tailles de texte ≥ 24 px) défini par le développeur ; l'IA n'y touche jamais. | Fiche § 7, § 8 |
| **Régie de scène** | Pilotage de la démo au clavier par le speaker (raccourcis). | Fiche § 6 |

## Écran

| Terme | Définition | Source |
|---|---|---|
| **Canevas (génératif)** | Zone centrale qui affiche les surfaces générées ; vide au départ. | Fiche § 6 |
| **Orbe (vocal)** | Indicateur animé de l'état de la conversation : Repos, Écoute, Réflexion, Parole, Interrompue, Micro coupé (~~Secours~~ : retiré, pdr-0032). | Fiche § 6 |
| **Rail des agents** | Zone qui montre l'orchestrateur et les agents ; un agent s'allume quand il est sollicité. Libellé maquette : « AGENTS A2A ». | Fiche § 6 ; maquettes |
| **Flux du protocole** | Zone qui liste les messages A2UI envoyés par les agents ; le message en cours est relié à son composant. Libellés : « panneau protocole », « panneau JSON », « FLUX A2UI ». | Fiche § 2, § 4, § 6 ; maquettes |
| **Étagère du catalogue** | Zone qui montre les composants disponibles ; celui qu'utilise l'agent s'allume. | Fiche § 6 |
| **Transcription** | Texte en direct des répliques du speaker et de l'IA, dans la barre supérieure. | Fiche § 6 |
| **Squelette** | Premier état visible d'une surface ou d'un composant pendant sa construction, avant les données. | Fiche § 4 (FR-04), § 7 |
| **Mutation** | Transformation d'une surface existante **sur place**, sans la recréer (badge « Muté »). | Fiche § 2 ; maquette 3 |
| **État neutre** | Affichage d'un composant qui a reçu des données incomplètes, à la place d'une erreur. | Fiche § 7 |

## Voix

| Terme | Définition | Source |
|---|---|---|
| **Barge-in** | Le speaker coupe la parole à l'IA en parlant ; l'IA se tait et écoute. | FR-13 ; [rt-barge-in] |
| **Interruption** | Résultat d'un barge-in ou du raccourci « silence » ; ne détruit pas les surfaces. | FR-15, FR-19, FR-20 |
| **Annulation** | « Stop » / « annule » : arrête la voix et la génération ; retire les surfaces inachevées. | FR-16 |
| **Correction** | Nouvelle consigne en cours de génération (« non, plutôt iOS ») qui réoriente sans repartir de zéro. | FR-17 |
| **Silence (raccourci)** | Touche qui fait taire l'IA sans fermer la session. | FR-20 |
| **AEC** | Annulation d'écho acoustique ; empêche l'IA de s'entendre dans la sono et de se couper. | [rt-echo-cancellation] |
| **Jeton éphémère** | Identifiant de session de courte durée fourni par le backend ; jamais de clé longue durée dans l'app. | NFR-09 ; [rt-ephemeral-keys] |

## Agents et protocoles

| Terme | Définition | Source |
|---|---|---|
| **Orchestrateur** | Agent qui comprend la demande, planifie et délègue aux agents spécialisés ; tourne côté backend. | Fiche § 3 ; [ma-target-architecture] |
| **Agent spécialisé** | Agent dédié à un domaine nommé par son rôle métier : Qualité, Voix du client, Livraison ([pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md)). Les maquettes utilisaient des noms de source (Crash, Avis stores, Changelog, Captures d'écran) — E1 tranché. L'orchestrateur choisit les agents qu'il active ; les autres restent en veille. | Fiche § 3 ; maquettes |
| **A2A** | Protocole Agent-to-Agent : transport des messages entre l'orchestrateur, les agents et le client. | [genui-a2a-connector] |
| **A2UI** | Protocole Agent-to-UI : JSON déclaratif qui décrit une interface (composants, données) sans code. Version : v0.9 ([pdr-0018](../decisions/pdr-0018-a2ui-v09-genui-0-10-4.md)). | [genui-a2ui-overview] |
| **GenUI** | Package Flutter (`genui`, `genui_a2a`) qui rend les messages A2UI avec les widgets du catalogue. | [genui-overview] |
| **Surface** | Zone d'UI générée, identifiée par un `surfaceId`, avec son propre modèle de données. Au plus 6 visibles (RG-05). | [genui-multiple-surfaces] ; fiche § 3 |
| **Catalogue** | Liste fermée de **6 composants** que l'IA peut utiliser ; le développeur en fixe l'apparence ([pdr-0014](../decisions/pdr-0014-six-component-catalog.md)). Identifié par un `catalogId` (maquette : `genesis.release`). La mise en page des surfaces n'en fait pas partie ([pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)). | Fiche § 7 ; [genui-catalog-ids] |
| **Composant** | Élément du catalogue, nommé comme dans la fiche (ex. Indicateur clé ; libellé de maquette : Carte KPI). | Fiche § 7 ; maquettes |
| **Data model / binding** | Données d'une surface, liées aux composants par chemin (ex. `/series/android`). | [genui-data-model] ; maquette 2 |

## Rejeu et secours

| Terme | Définition | Source |
|---|---|---|
| **Enregistrement** | Capture du flux A2UI d'une session (ni voix ni transcription : Q-18, [pdr-0032](../decisions/pdr-0032-obs-video-fallback-a2ui-replay-act.md)). | FR-09 |
| **Rejeu** | Relecture d'une génération enregistrée, de 0,25× à 2×, avec un curseur. | FR-09, fiche § 6 |
| **Mode secours** | ~~Rejeu d'une session enregistrée déclenché par un raccourci quand le direct échoue ; indicateur discret.~~ Retiré (pdr-0032) : le secours est une vidéo OBS gérée par le porteur. | ~~FR-10, NFR-07~~ |
| **Répétition** | Exécution complète de la démo hors scène, qui sert à mesurer les NFR et à valider la DoD. | Fiche § 5, § 8 |
