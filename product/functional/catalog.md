---
id: p-fn-catalog
title: Catalogue de composants
area: functional
status: validated
updated: 2026-10-31
sources: [specs/012-llm-composer-crashlist/status.md, specs/012-llm-composer-crashlist/spec.md, contracts/a2ui/genesis/v1/README.md, specs/009-j5-act3-interact/status.md, specs/009-j5-act3-interact/plan.md, specs/008-j4-act2-transform/status.md, specs/008-j4-act2-transform/plan.md, specs/007-j3-act1-frontend/spec.md, specs/007-j3-act1-frontend/status.md, specs/006-j3-act1-backend/plan.md, specs/006-j3-act1-backend/status.md, contracts/a2ui/genesis/v1/README.md, product/sources/product-description.pdf#p10, product/sources/product-description.pdf#p11, product/sources/design-example.pdf]
links: [pdr-0074-012-llm-composer-gateway-crashlist-details, p-fn-feature-llm-composer-012, p-ar-llm-composer, pdr-0070-llm-composer-and-crashlist-012, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0061-action-bar-appears-end-of-act-2, pdr-0064-008-act2-transform-details-assistant-decided, p-fn-dataset-acts, p-ar-app-channel-contract, p-ar-frontend-screen, pdr-0053-client-side-a2ui-validation-from-007, pdr-0054-stage-screen-orb-acts-checklist, p-ar-backend, p-rm-roadmap, pdr-0017-source-hierarchy-sheet-over-mockups, genui-data-model, p-fn-business-rules, p-fn-mockups, p-fn-dataset, p-fn-screen, pdr-0007-closed-catalog-stage-theme, p-rm-open-questions, genui-custom-catalog-item, genui-catalog-ids, genui-a2ui-security, ux-genui-catalog-as-ds, ux-genui-errors-validation, pdr-0014-six-component-catalog, pdr-0015-app-held-canvas-layout, pdr-0016-validate-release-action, pdr-0019-six-limit-applies-to-surfaces, pdr-0020-act1-four-surfaces, pdr-0039-component-voice-interactions-via-fr07]
tags: [catalogue, composants, a2ui, genui, theme]
---
# Catalogue de composants

**En bref.** L'IA compose **uniquement** avec un catalogue fermé. Elle choisit quels composants afficher et avec quelles données, mais leur apparence est définie à l'avance. C'est le message clé du talk : le développeur garde la main sur le rendu (fiche § 7, p. 10). Décisions : principe [pdr-0007](../decisions/pdr-0007-closed-catalog-stage-theme.md) ; contenu [pdr-0014](../decisions/pdr-0014-six-component-catalog.md) (6 composants, E2 · Q-02 et E21 · Q-60 tranchés) ; mise en page par l'app [pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md) (pas de `Grid`).

## Le catalogue retenu (référence, 6 composants)

Noms de la fiche, comportement des maquettes ([pdr-0014](../decisions/pdr-0014-six-component-catalog.md)).

| Composant | Agent | Actes | Comportement |
|---|---|---|---|
| **Indicateur clé** | Qualité | 1, 2 | Muté à l'acte 2 : ligne de comparaison avec la 3.3 (`comparison`), valeur Android |
| **Courbe de tendance** | Qualité | 1, 2 | Mutée à l'acte 2 : deux séries « Android 3.4 » et « Android 3.3 » et ligne de seuil ; une seule série « iOS 3.4 » après la correction |
| **Sentiment des avis** | Voix du client | 1, 2 | Répartition positifs / négatifs + 3 extraits (fiche) ; muté à l'acte 2 : ligne de comparaison des avis négatifs avec la 3.3 (`comparison`) ; extraits de la vue (Android, puis iOS) |
| **Checklist go/no-go** | Livraison | 1, 2, 3 | Valeurs qui citent la 3.3 et « NO-GO Android » à l'acte 2 (« GO iOS » après la correction) ; passe à « Bloquée » ou « Validée » à l'acte 3 par le seul sous-chemin `decisionStatus` (RG-28, RG-30) ; ligne « Changelog validé · 37 PR » |
| **Barre d'actions** | Livraison | 2 (apparition), 3 | « Bloquer la release » (RG-28) et « Valider la release » (RG-30, [pdr-0016](../decisions/pdr-0016-validate-release-action.md)) ; créée par Livraison à la fin de l'acte 2 ([pdr-0061](../decisions/pdr-0061-action-bar-appears-end-of-act-2.md)), livrée par 009 |
| **Liste des crashs** | Qualité | aucun (hors des trois actes) | **Livrée par 012 (2026-10-31)** : hors scénario principal, l'IA la choisit quand le speaker la demande (« Affiche la liste des crashs », avec ou sans plateforme) ; jamais à l'acte 1. Données : top 5 des crashs de la 3.4 ([p-fn-dataset](dataset.md)) ; détail § « Liste des crashs » ci-dessous |

Écartés : Comparatif de versions (la comparaison passe par la mutation des surfaces existantes), En-tête de release (version et statut visibles par le titre du canevas et la checklist), Timeline des maquettes. `Grid` n'est pas un composant : l'app place les surfaces ([pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)). La limite « 6 » porte sur les surfaces visibles, pas sur l'étagère ([pdr-0019](../decisions/pdr-0019-six-limit-applies-to-surfaces.md)). L'acte 1 compose 4 surfaces : Indicateur clé, Courbe de tendance, Sentiment des avis, Checklist go/no-go ([pdr-0020](../decisions/pdr-0020-act1-four-surfaces.md)).

## Contrat exécutable du catalogue `genesis` v1 (J3-A, 006)

Le catalogue est maintenant un **contrat testé** : `contracts/a2ui/genesis/v1/` (`catalog.json`, `examples/act1-*.jsonl`, `act2-*.jsonl`, `correction-ios-*.jsonl`, README) ; messages, validation et configuration : [p-ar-app-channel-contract](../architecture/app-channel-contract.md). Les **noms techniques** des types sont une conception de l'assistant, jamais calqués sur les maquettes ([pdr-0017](../decisions/pdr-0017-source-hierarchy-sheet-over-mockups.md)).

| Composant (fiche) | Type A2UI | Surface | Agent | Liaison `data` | Dans `components` (liste blanche J3) |
|---|---|---|---|---|---|
| Indicateur clé | `KeyIndicator` | `kpi` | Qualité | `{path: "/kpi"}` | oui |
| Courbe de tendance | `TrendChart` | `trend` | Qualité | `{path: "/trend"}` | oui |
| Sentiment des avis | `ReviewSentiment` | `reviews` | Voix du client | `{path: "/reviews"}` | oui |
| Checklist go/no-go | `ReleaseChecklist` | `checklist` | Livraison | `{path: "/checklist"}` | oui |
| Barre d'actions | `ActionBar` | `actions` (009) | Livraison | `{path: "/actions"}` | oui |
| Liste des crashs | `CrashList` | `crashes` (012) | Qualité | `{path: "/crashes"}` | oui (en dernier) |

- **Deux listes** : `components` (**6 depuis 012**, tous ont un schéma ; valeur de `A2UI_COMPONENTS`, `CrashList` en dernier) et `catalogComponents` (les **6** de [pdr-0014](../decisions/pdr-0014-six-component-catalog.md)). L'étagère (FR-06, 007) se construit sur `catalogComponents`, le validateur sur `components` ; les deux listes sont désormais égales (elles différaient de 4 à 5 composants avant 012).
- **Composants plats** : une surface = un composant `root` lié à son chemin (`data: {path}`), sans `Column` ni `Text` ; couleurs et tailles viennent du thème de scène (RG-09).
- **Statuts** : codes fermés `ok` | `risk` | `blocking` (validé / à risque / bloquant) accompagnés d'un libellé séparé (`statusLabel`, `levelLabel`) ; aucune couleur côté client ne dépend d'un libellé français. Checklist : `items[].level`, `recommendation {level, label}`, `decisionStatus`. Statuts tranchés (Q-35 → [pdr-0054](../decisions/pdr-0054-stage-screen-orb-acts-checklist.md)) ; libellés du statut global : voir [p-fn-dataset](dataset.md).
- **Trois temps (RG-02)** : squelette (`createSurface` puis composant sans donnée), composants, données (`updateDataModel` du chemin entier). Le backend ne garantit que l'**ordre** ; le squelette est rendu visible côté app par 007 (§ ci-dessous). `sendDataModel: false`.
- **Acte 2 (008, 2026-10-30)** : les fixtures `act2-*` (Android 3.4 avec comparaison 3.3) et `correction-ios-*` (iOS 3.4, sans comparaison) ne contiennent **qu'un `updateDataModel` du chemin entier** par surface, jamais de `createSurface`, `deleteSurface` ni `updateComponents` ([pdr-0064](../decisions/pdr-0064-008-act2-transform-details-assistant-decided.md) D1). Elles se rejouent **après l'acte 1** ; **seules, elles sont invalides** (`unknown_surface`). Le champ facultatif `comparison {label, value, delta}` (KPI et avis, trois chaînes requises) est lu par l'app ; valeurs : [p-fn-dataset-acts](dataset-acts.md).
- **Acte 3 (009, 2026-10-30)** : `ActionBar` (surface `actions`, chemin `/actions`) porte `{title, actions[{id, label, tone}]}`, tous champs requis ; `id` dans l'ensemble fermé `block_release|validate_release`, `tone` dans `neutral|danger` (couleur par ton, jamais par libellé, RG-09). Fixtures `act2-actions` (trois temps, créée par Livraison dans la tâche de l'acte 2), `act3-block` et `act3-validate` (un `updateDataModel` du seul sous-chemin `/checklist/decisionStatus`). **Sous-chemins inscriptibles** : `catalog.json` déclare `writableSubPaths` (aujourd'hui `/checklist/decisionStatus`, type `string`) ; un `updateDataModel` n'écrit que `/<surface>` ou un sous-chemin déclaré du bon type, sinon code fermé **`path_not_allowed`** (validateurs Go et Dart, quatre fixtures négatives communes). C'est l'exception au « chemin entier » de [pdr-0064](../decisions/pdr-0064-008-act2-transform-details-assistant-decided.md) D1, justifiée par l'agent sans état ([pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md) D3). Valeurs : [p-fn-dataset-acts](dataset-acts.md).
- **Valeurs** : chaînes déjà formatées à la française (« 99,57 % », « −0,36 pt »), nombres JSON pour les séries ; calculées par le backend depuis le jeu de données.

## Rendu côté app : trois états par composant (007, 2026-10-30)

Livré par la fonctionnalité 007 ; implémentation : [p-ar-frontend-screen](../architecture/frontend-screen.md). Les six composants du contrat (`components`) sont rendus ; `CrashList` (012) l'est aussi, et l'étagère le montre « inutilisé » tant que la liste n'a pas été demandée.

| État | Quand | Rendu |
|---|---|---|
| **Squelette** (RG-02) | de `createSurface` à `updateComponents` | emplacement de la surface, bloc de chargement du thème de scène, peint à la frame qui suit `createSurface` |
| **Sans données** | composants reçus, objet lié absent (`updateComponents` sans `updateDataModel`) | cellule vide du thème de scène, distincte du squelette |
| **Neutre** (RG-10) | objet incomplet, champ de mauvais type, code de statut hors `ok\|risk\|blocking` | état neutre du composant, **sans message d'erreur ni exception** ; la démo continue |

- **Données incomplètes (RG-10)** : un champ requis du contrat (`catalog.json`, y compris dans les `series`, `excerpts`, `items`, `recommendation`) manquant donne l'état neutre ; les champs inconnus sont tolérés. Un `comparison` incomplet (label, value ou delta absent) omet **seulement sa ligne** : le composant reste complet, sans état neutre global (D7). Le statut se lit sur le **code** (`ok|risk|blocking`), jamais sur le libellé français.
- **Troncature honnête de la checklist** : quand tous les critères ne tiennent pas, les critères `blocking` puis `risk` sont gardés en priorité (ordre d'origine conservé) et la dernière ligne annonce **« + N autres critères »** ; jamais de ligne rognée en silence. Acte 1 : 3 critères, qui tiennent.
- **Acte 2 à l'écran (008)** : sous la valeur du KPI et sous la répartition des avis, une ligne `comparison-<surface>` (un seul `Text` : « 3.3 : 99,71 % · −0,28 pt », « 3.3 : 14 % négatifs · +16 pts »), en couleur neutre, jamais déduite du texte du `delta` (RG-09). La courbe a une légende par série (`trend-series-<nom>`), des couleurs **par plateforme** (palette sans couleur de statut) et la série 3.3 en pointillés (D8). Dans la checklist, la valeur d'un critère prend sa largeur avant le seuil et le libellé : la citation de la 3.3 n'est jamais tronquée (NFR-05). Détail : [p-ar-frontend-screen](../architecture/frontend-screen.md).
- **Barre d'actions à l'écran (009)** : mêmes trois états que les autres composants (squelette, sans données, neutre). Deux boutons (texte ≥ 24 px, cible ≥ 48 px, libellé sur une ligne tronqué par l'ellipse s'il est trop long), bordure et texte par ton (`neutral`, `danger` : jetons du thème de scène `actionNeutralBorder`, `actionDangerBorder`, couleurs choisies par la boucle, contrastes mesurés). Les deux boutons sont **inactifs** pendant une action (clic envoyé, agent au travail) et redeviennent actifs à la fin ; un nouveau clic est permis ensuite (« Bloquer » puis « Valider » donne « Validée »). Un `id` inconnu donne l'état neutre (RG-10). Libellés lus dans la donnée, jamais codés. Implémentation : [p-ar-frontend-screen](../architecture/frontend-screen.md).
- **Autres débordements** : une ligne par libellé, ellipse au-delà (`maxLines`), jamais de réduction sous 24 px (NFR-05).
- **Emplacements déterministes** (l'app place les surfaces, [pdr-0015](../decisions/pdr-0015-app-held-canvas-layout.md)) : `kpi`, `trend`, `reviews`, `checklist` dans cet ordre, puis les surfaces inconnues dans leur ordre d'arrivée ; **2×2** jusqu'à 4 surfaces de la grille, **3×2 dès la cinquième** (NFR-06) : `crashes` s'ajoute après `checklist` (012, cinquième cellule) ; la grille est tenue par **un parent unique** pour que les quatre surfaces existantes gardent leur `State` en passant de 2×2 à 3×2. Depuis 009, la **Barre d'actions** n'est pas dans la grille : c'est un **bandeau de 72 px sous la grille**, réservé dès la première surface, pour que les quatre surfaces de l'acte 1 gardent position et état de rendu ([pdr-0065](../decisions/pdr-0065-009-act3-interact-details-assistant-decided.md) D7, S-02).
- **Défense en profondeur** : un message hors catalogue (composant, propriété, liaison littérale) est refusé par le validateur client avant le moteur ([pdr-0053](../decisions/pdr-0053-client-side-a2ui-validation-from-007.md)) ; le canevas ne montre alors aucune surface pour ce message et le panneau du protocole le marque « refusé ».
- **Écart consigné** : stories Widgetbook et goldens par composant reportés ([p-ar-frontend-screen](../architecture/frontend-screen.md), coupes C1 et C3 de la roadmap).

## Liste des crashs (012, 2026-10-31)

Livrée par la fonctionnalité 012 ([pdr-0070](../decisions/pdr-0070-llm-composer-and-crashlist-012.md), mécanisme [pdr-0074](../decisions/pdr-0074-012-llm-composer-gateway-crashlist-details.md) D5, D9, D10) ; scénarios C-04 à C-08, F-01, F-02 : [p-fn-feature-llm-composer-012](features/llm-composer-012.feature). Elle répond à l'observation de l'essai au micro du porteur : « Le composant Crashlist n'est jamais apparu, même après l'avoir demandé explicitement ».

| Point | Livré |
|---|---|
| Schéma | surface `crashes`, chemin `/crashes` `{title, items[{rank, label, platform, volume, sessions}]}`, tous champs requis ; `items` de 0 à 5 lignes ([contrat](../../contracts/a2ui/genesis/v1/README.md)) |
| Données | recopiées du top 5 de [p-fn-dataset](dataset.md) (`dataset.json` `crashes`), jamais rédigées par le modèle (NFR-08, RG-24) |
| Demande | « Affiche la liste des crashs » ; plateforme nommée = filtre (rangs renumérotés 1 à n, titre « Principaux crashs · 3.4 », « · Android » ou « · iOS ») ; la liste ne déplace pas le focus de l'acte 2 et n'en hérite pas |
| Trois états | squelette, sans données, neutre (`items` de mauvais type ou ligne sans libellé : « Données indisponibles », RG-10) |
| Ligne | rang, libellé sur **une ligne** puis ellipse, **plateforme et volume à droite** ; `sessions` reste dans le contrat et les données mais **n'est pas affiché** (la fiche demande plateforme et volume ; D10, pdr-0062) ; texte ≥ 24 px |
| Écran | cinquième cellule de la grille **3×2** ; étagère « 5 / 6 utilisés » (« 6 / 6 » avec la Barre d'actions) |
| Refus | une vue que le catalogue ne produit pas (carte, camembert…) est refusée à la voix avec une alternative (RG-08) : [Q-81](../roadmap/open-questions.md) |
| Limite connue | en grille 3×2, la checklist et les avis passent dans des cellules plus étroites (~620 px) : libellés tronqués ; à traiter par 013 ([Q-83](../roadmap/open-questions.md)) |

## Historique : les 8 composants de la fiche (§ 7)

*Table source, conservée pour mémoire ; le catalogue retenu est ci-dessus.*

| Composant | Ce qu'il affiche | Ce que l'utilisateur peut faire | Acte |
|---|---|---|---|
| **En-tête de release** | Numéro de version, date cible, statut global (en préparation, prête, bloquée) | Lire uniquement | 1 |
| **Indicateur clé** | Une valeur, sa tendance et son seuil (taux de sessions sans crash, note moyenne) | Demander le détail à la voix | 1, 2 |
| **Courbe de tendance** | L'évolution d'un indicateur, avec comparaison possible entre deux versions | Demander une autre période ou plateforme | 1, 2 |
| **Liste des crashs** | Les crashs les plus fréquents, avec plateforme et volume | Filtrer par plateforme à la voix | 1, 2 |
| **Sentiment des avis** | La répartition des avis positifs et négatifs, avec 3 extraits | Demander les avis d'une plateforme | 1, 2 |
| **Comparatif de versions** | Ce qui a changé entre deux versions (fonctionnalités, correctifs) | Lire uniquement | 2 |
| **Checklist go/no-go** | Les critères de release et leur statut (validé, à risque, bloquant) | Lire ; le statut évolue après une action | 1, 3 |
| **Barre d'actions** | Les décisions possibles : « Bloquer la release », « Valider la release » | Cliquer ; l'IA confirme à la voix | 3 |

## Règles fonctionnelles du catalogue (fiche § 7)

| Règle (fiche) | RG |
|---|---|
| L'IA ne peut pas inventer de composant hors de ce catalogue. Une demande impossible est refusée à la voix, avec une alternative. | RG-07, RG-08 |
| Les couleurs et tailles de texte viennent du thème de scène, jamais de l'IA. | RG-09 |
| Si un composant reçoit des données incomplètes, il affiche un état neutre plutôt qu'une erreur, et la démo continue. | RG-10 |
| Chaque composant possède un état squelette, visible pendant sa construction. | RG-02 |

Détails : [p-fn-business-rules](business-rules.md).

Les interactions vocales de la colonne « Ce que l'utilisateur peut faire » (détail d'un indicateur, autre période ou plateforme, filtre des crashs, avis d'une plateforme) sont couvertes par FR-07 uniquement (Q-61 tranchée, [pdr-0039](../decisions/pdr-0039-component-voice-interactions-via-fr07.md)). « Valider la release » : tranché (RG-30, pdr-0016).

## Historique : le catalogue des maquettes (6 composants)

*Conservé pour mémoire ; E2 et E21 sont tranchés par pdr-0014.*

L'étagère des maquettes affiche 6 composants, avec leur type A2UI quand il est visible :

| Libellé maquette | Type A2UI visible | Surface (maquette) | Correspondance **apparente** avec la fiche |
|---|---|---|---|
| Carte KPI | `KpiCard` | `s-kpi` | Indicateur clé |
| Courbes | `LineChart` (puis `LineChart v2`) | `s-crash-trend` | Courbe de tendance |
| Liste d'avis | `ReviewList` | `s-reviews` | Sentiment des avis — ⚠️ la fiche décrit une répartition positifs / négatifs avec 3 extraits ; la maquette 2 montre une liste, la maquette 3 trois segments (négatif, neutre, positif) et un seul thème (E21 · Q-60) |
| Checklist | — | `s-decision` | Checklist go/no-go |
| Timeline | `Timeline` | `s-changelog` | aucune (proche de Comparatif de versions ?) |
| Bouton d'action | — | `s-decision` | Barre d'actions |
| *(racine)* | `Grid` (`board`, 2 colonnes) | `release-3-4` | aucune |

Sans équivalent dans les maquettes : **En-tête de release**, **Liste des crashs**, **Comparatif de versions**. Le `catalogId` visible est `genesis.release` (maquette 1).

La correspondance ci-dessus est une lecture de l'assistant, gardée pour mémoire ; la décision est pdr-0014. Voir [p-fn-mockups](mockups.md), [p-rm-open-questions](../roadmap/open-questions.md).

## Repères techniques (knowledge)

- Un composant de catalogue genui = nom + schéma JSON + `widgetBuilder` : [genui-custom-catalog-item].
- Le `catalogId` est un contrat entre agent et client : [genui-catalog-ids].
- Le catalogue est une liste blanche et une frontière de sécurité : [genui-a2ui-security].
- Traiter le catalogue comme une partie du design system : [ux-genui-catalog-as-ds].
- Erreurs de validation et états dégradés : [ux-genui-errors-validation].
