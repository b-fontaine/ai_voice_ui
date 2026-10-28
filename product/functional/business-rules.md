---
id: p-fn-business-rules
title: Règles de fonctionnement RG-01 à RG-30
area: functional
status: draft
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p11, product/sources/product-description.pdf#p12]
links: [p-fn-requirements, p-fn-nfr, p-fn-catalog, p-fn-screen, p-fn-risks-acceptance, pdr-0005-frozen-fictional-dataset, pdr-0006-replay-fallback-must, pdr-0007-closed-catalog-stage-theme, pdr-0009-french-only, rt-barge-in, genui-multiple-surfaces, ux-genui-streaming-loading, ux-genui-errors-validation, ma-filler-acknowledgements, pdr-0013-orchestrator-visible-agent-selection, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action]
tags: [regles, fonctionnement, interruption, catalogue, rejeu]
---
# Règles de fonctionnement

**En bref.** Les règles qui gouvernent le comportement de Genesis Canvas, dégagées de la fiche. Certaines y sont explicites, d'autres découlent d'une exigence ou d'une parade. Chaque règle cite sa source. Le **libellé** est une synthèse de l'assistant (statut `draft`) ; le **fond** vient de la fiche.

## Construction de l'écran

| RG | Règle | Source |
|---|---|---|
| RG-01 | Au démarrage, et après une remise à zéro, le canevas est vide : seul l'orbe vocal animé est visible. | FR-01, § 6 (canevas « vide au départ ») |
| RG-02 | Toute surface passe par trois temps visibles : squelette, puis composants, puis données. Chaque composant du catalogue possède un état squelette. | FR-04, § 7 (règles du catalogue) |
| RG-03 | Le premier squelette apparaît en moins de 1,5 s après la fin de la phrase, avant toute donnée. | NFR-02, § 8 (« squelettes immédiats ») |
| RG-04 | L'IA commente pendant la construction (« je lance l'analyse des crashs... ») : l'attente devient du spectacle. | § 5 (point délicat), § 8 (risque « attente trop longue ») |
| RG-05 | Au maximum 6 surfaces sont visibles en même temps. | § 3, § 6, NFR-06 ; ⚠️ écart E4 · Q-04 |
| RG-06 | Une demande de modification transforme les surfaces existantes **sur place** : elles restent à leur place et ne sont pas recréées. | FR-07, § 2 acte 2, S-02 ; ⚠️ écarts E8 · Q-21 et E19 · Q-58 |
| RG-25 | La fabrication est montrée en continu : l'agent sollicité s'allume avec sa tâche, le message de protocole en cours est mis en évidence et relié à son composant, le composant utilisé s'allume dans l'étagère, la transcription est affichée en direct. | FR-02, FR-03, FR-05, FR-06, § 6 |
| RG-29 | L'orchestrateur choisit à chaque demande les agents qu'il active, et le rail le montre : agents sollicités allumés avec leur tâche, agents non sollicités visiblement en veille. Les agents portent un nom de rôle métier (Qualité, Voix du client, Livraison). | FR-03, [pdr-0013](../decisions/pdr-0013-orchestrator-visible-agent-selection.md) |

## Catalogue et apparence

| RG | Règle | Source |
|---|---|---|
| RG-07 | L'IA ne compose qu'avec les composants du catalogue ; elle ne peut pas en inventer. | § 3 (hors périmètre), § 7 |
| RG-08 | Une demande impossible avec le catalogue est **refusée à la voix, avec une alternative**. | § 7 |
| RG-09 | Couleurs et tailles de texte viennent du **thème de scène**, jamais de l'IA ; texte ≥ 24 px, contraste WCAG AA. | § 7, NFR-05, § 8 |
| RG-10 | Un composant qui reçoit des données incomplètes affiche un **état neutre** plutôt qu'une erreur ; la démo continue. | § 7 |

## Interruption, annulation, correction

| RG | Règle | Source |
|---|---|---|
| RG-11 | Quand le speaker parle pendant que l'IA parle, l'IA se tait immédiatement et écoute. | FR-13, S-05 |
| RG-12 | Après une interruption, la nouvelle phrase devient la consigne en vigueur. | FR-14 |
| RG-13 | Une interruption ne détruit jamais les surfaces déjà construites. | FR-15, S-05 |
| RG-14 | « Stop » ou « annule » arrête la voix **et** la génération en cours ; les surfaces inachevées sont retirées proprement ; les surfaces complètes restent. | FR-16, S-06 |
| RG-15 | Une correction en cours de génération (« non, plutôt iOS ») réoriente la génération : les surfaces déjà construites passent sur les nouvelles données, sans repartir d'un canevas vide. | FR-17, S-07 |
| RG-16 | Un bruit court (toux, applaudissements d'une seconde, rire) n'interrompt pas l'IA. | FR-18, S-08, § 8 (seuil réglé en répétition) |
| RG-17 | Une interruption est visible : l'orbe passe par « Interrompue » (arrêt net, bref flash) puis « Écoute » ; la réplique de l'IA est tronquée dans la transcription là où elle a été coupée. | FR-19, § 6 (états de l'orbe) |
| RG-27 | Les répliques de l'IA sont **courtes**, par consigne. | § 8 (parade « l'IA ne s'arrête pas ») |

Repère technique : couper la voix n'annule pas d'elle-même les outils en cours ; RG-14 impose donc une annulation explicite de la génération ([rt-barge-in]).

## Interaction avec l'UI générée

| RG | Règle | Source |
|---|---|---|
| RG-18 | Un clic sur un composant généré est transmis à l'agent concerné, qui s'allume dans le rail et répond à la voix **et** dans l'interface. | FR-08, § 6 (modes), S-03 |
| RG-28 | Le statut de la checklist go/no-go évolue après une action (ex. « Bloquer la release » → statut « Bloquée »). | § 7 (checklist), S-03 ; ⚠️ écart E17 · Q-35 |
| RG-30 | « Valider la release » se comporte comme « Bloquer la release » (RG-18, RG-28) : clic transmis à Livraison, confirmation vocale, statut de la checklist mis à jour (par exemple « Validée »). | § 7 (Barre d'actions) ; [pdr-0016](../decisions/pdr-0016-validate-release-action.md) (Q-62) |

## Régie de scène et secours

| RG | Règle | Source |
|---|---|---|
| RG-19 | Toute la génération est enregistrée et rejouable de 0,25× à 2×. | FR-09, § 6 (zone rejeu) |
| RG-20 | Le mode secours rejoue une session enregistrée ; il s'active par un seul raccourci, en moins de 2 s, sans redémarrer l'app, et un indicateur discret le signale. | FR-10, NFR-07, S-04, § 8 |
| RG-21 | Toute action critique a un raccourci clavier ; le clavier est réservé au speaker. | NFR-12, § 6 |
| RG-22 | Couper le micro (FR-12) ou faire taire l'IA au clavier (FR-20) **ne ferme pas** la session. | FR-12, FR-20, S-09 |
| RG-23 | Un raccourci remet le canevas à l'état vide (retour à RG-01). | FR-11 |

## Données et langue

| RG | Règle | Source |
|---|---|---|
| RG-24 | Les données sont fictives et figées : seule la composition de l'UI varie d'une exécution à l'autre. | NFR-08, § 3 ; [pdr-0005](../decisions/pdr-0005-frozen-fictional-dataset.md) |
| RG-26 | La conversation et l'interface sont en français uniquement. | § 3 ; [pdr-0009](../decisions/pdr-0009-french-only.md) |

## Numérotation

Les RG sont numérotées dans l'ordre de rédaction, puis regroupées par thème. On ne renumérote jamais une règle : une règle abandonnée est barrée et garde son numéro. Prochaine règle libre : **RG-31**.

## Points ouverts

- RG-05 : le plafond de 6 porte-t-il sur les surfaces ou sur les composants de l'étagère ? (E4 · Q-04)
- RG-06 : la maquette de l'acte 2 retire une surface et en crée une nouvelle (E8 · Q-21) ; elle garde aussi un critère iOS (99,71) alors que S-02 exige des données « uniquement Android » (E19 · Q-58).
- RG-17 : la fiche affiche la réplique de l'IA (tronquée si coupée) dans la barre supérieure ; les maquettes n'en montrent aucune (E20 · Q-59).
- Interactions vocales propres à chaque composant (fiche § 7 : détail d'un indicateur, autre période ou plateforme, filtre des crashs, avis d'une plateforme) : aucune règle ne les porte tant que leur place dans le MVP n'est pas décidée (Q-61).
- RG-14 / RG-15 : modèle de surfaces tranché (E11 · Q-29, [pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)) : N surfaces dans une grille de l'app ([genui-multiple-surfaces]).

Tous renvoient à [p-rm-open-questions](../roadmap/open-questions.md).
