# Contrat du catalogue `genesis` (v1)

Ces fixtures sont le **contrat exécutable** entre les agents A2A, l'orchestrateur et le client Flutter (spec 006, amendement A3). Les exemples d'écrans de l'acte 1 servent aussi d'exemples guidés au sens de pdr-0023.

- `catalog.json` : les 6 composants validés (`components`, dans cet ordre, est la valeur de `A2UI_COMPONENTS`), propriétés admises (`id`, `component`, `data`), liaison `data = {"path": "/<surface>"}` et forme du data model de chaque surface. Les codes de statut sont fermés (`ok|risk|blocking`) et accompagnés d'un libellé séparé ; aucune couleur ne dépend d'un libellé français (RG-09).
- `examples/act1-*.jsonl` : une ligne JSON par message A2UI v0.9, dans l'ordre des trois temps (RG-02) : `createSurface`, `updateComponents` (composant `root`, donnée absente), `updateDataModel` (chemin racine de la surface, valeur complète). Valeurs : `product/functional/dataset.md`, acte 1.
- `examples/act2-*.jsonl` et `examples/correction-ios-*.jsonl` (spec 008) : **un seul** message `updateDataModel` par fichier (chemin racine de la surface, valeur complète, jamais de sous-chemin), pour les quatre surfaces `kpi`, `trend`, `reviews`, `checklist`. Ils ne contiennent ni `createSurface` ni `updateComponents` : les surfaces de l'acte 1 sont réutilisées. Valeurs : `product/functional/dataset.md`, § Acte 2 et § vue iOS. `act2-*` (Android 3.4) porte, pour l'indicateur clé et les avis, le champ facultatif `comparison` (`label`, `value`, `delta`, tous requis) avec la 3.3 ; `correction-ios-*` (iOS 3.4) n'a **pas** de `comparison` (le jeu ne contient pas de 3.3 pour iOS) et sa courbe n'a qu'une série.

`catalogComponents` liste les 6 composants du catalogue de pdr-0014 ; depuis la spec 012 (`CrashList` a désormais son schéma), `components` les liste aussi tous les six, `CrashList` en dernier. L'étagère de l'app se construit sur `catalogComponents`, le validateur sur `components`.

## Remplacement de `${CATALOG_ID}`

Le texte `${CATALOG_ID}` est un placeholder (l'identifiant réel est provisoire, Q-44, et vient de la configuration `A2UI_CATALOG_ID`). Tout consommateur le remplace, **textuellement et partout**, par l'identifiant configuré avant de lire une ligne ou d'attendre une égalité.

Les fixtures ne doivent jamais contenir d'identifiant réel.

## Fixtures négatives (`invalid/`)

Chaque fichier `invalid/*.jsonl` est une séquence de messages (une ligne JSON chacune, `${CATALOG_ID}` à remplacer comme ci-dessus) à rejouer, dans l'ordre, sur un validateur neuf : tous les messages sont acceptés sauf le dernier, qui est refusé avec le code que `invalid/expected.json` associe au nom du fichier (codes fermés du validateur Go ; `too_large.jsonl` dépasse volontairement 64 Kio, la limite d'un message). Le validateur Go et le validateur Dart partagent ces fixtures (parité des refus).

## Rejeu de l'acte 2 et de la correction iOS

Les fixtures `act2-*` et `correction-ios-*` se rejouent **après** l'acte 1, sur le même état (même validateur, même registre de surfaces), dans cet ordre : acte 1, acte 2, correction iOS. **Seules, elles sont invalides** : rejouées sur un validateur neuf, elles sont refusées avec `unknown_surface`, puisque la surface n'existe pas encore. La parité Go/Dart porte sur cette séquence complète (acte 1, puis acte 2, puis correction iOS : tous les messages acceptés, aucune surface créée après l'acte 1) et sur le refus de chaque fixture seule.

## Acte 3 : Barre d'actions et décision (spec 009)

- `examples/act2-actions.jsonl` : la surface `actions` en trois temps (`createSurface`, `updateComponents` avec un composant `root` plat `ActionBar`, `updateDataModel` du chemin `/actions`). Elle est créée par l'agent Livraison pendant l'acte 2 (tâche Livraison), jamais avant ; elle ne compte pas parmi les quatre surfaces de l'acte 1. Champs : `title` et `actions[] {id, label, tone}`, tous requis ; `id` appartient à l'ensemble fermé `block_release|validate_release`, `tone` à `neutral|danger`.
- `examples/act3-block.jsonl` et `examples/act3-validate.jsonl` : **un seul** `updateDataModel` de surface `checklist`, chemin `/checklist/decisionStatus`, valeur « Bloquée » ou « Validée » (libellés de `dataset.json`). Critères, recommandation et comparaison restent affichés tels quels.

**Sous-chemins inscriptibles (pdr-0065 D3 contre pdr-0064 D1).** Un `updateDataModel` n'écrit que l'objet entier de la surface (chemin `"/" + surfaceId`, par exemple `/checklist`) ou un sous-chemin déclaré par `catalog.json` dans `definitions.<C>.dataModel.writableSubPaths` (clé = chemin complet, valeur = type JSON attendu). Aujourd'hui un seul : `/checklist/decisionStatus` (type `string`), écrit par l'agent Livraison, qui est sans état et ne sait pas quelle vue est affichée. Tout autre chemin (autre sous-chemin, sous-chemin d'une autre surface, chemin absent, vide ou `/`) ou toute valeur d'un autre type est refusé avec le code fermé `path_not_allowed` ; un pointeur mal formé reste `bad_pointer`. La règle est appliquée par les deux validateurs : Go (variable `A2UI_WRITABLE_SUBPATHS`, entrées `chemin:type` séparées par des virgules, valeur par défaut du compose égale à `catalog.json` et contrôlée par `backend/check-compose.sh`) et Dart (`GenesisContract.writableSubPaths`, comparé à `catalog.json` par un test). Une liste vide interdit tout sous-chemin. Fixtures négatives communes : `invalid/subpath-other`, `subpath-wrong-type`, `path-empty`, `path-slash`.

**Rejeu.** `act2-actions` se rejoue pendant ou après l'acte 2 ; `act3-*` se rejouent **après** les actes 1 et 2 (et la création de `actions`), dans le même état. Seuls, les `act3-*` sont refusés avec `unknown_surface`. Une seconde décision (Bloquer puis Valider) est permise : `act3-validate` après `act3-block`.

## Liste des crashs (spec 012)

- `examples/crashlist-global.jsonl` (top 5 de la 3.4, titre « Principaux crashs · 3.4 ») et `examples/crashlist-android.jsonl` (les 3 crashs Android, rangs 1 à 3, titre « Principaux crashs · Android ») : la surface `crashes` en trois temps (`createSurface`, `updateComponents` avec un composant `root` plat `CrashList`, `updateDataModel` du chemin `/crashes`). Valeurs : `product/functional/dataset.md`, § Liste des crashs. Elles ne font pas partie de l'acte 1 : la surface est créée à la demande (« liste des crashs »), sur un validateur neuf ou après les autres.
- Champs : `title` et `items[] {rank, label, platform, volume, sessions}`, tous requis. `rank` va de 1 à 5 et est **renuméroté après filtre** (la liste Android compte les rangs 1 à 3) ; `items` compte de 1 à 5 lignes (5 par défaut). `volume` = occurrences, `sessions` = sessions distinctes touchées.
- Pas de fixture négative dédiée (A8) : un `items` mal typé ou une ligne sans libellé se vérifient par les tests de rendu Dart (état neutre, RG-10) et par les tests des builders Go ; une propriété inconnue est déjà couverte par `invalid/bad_property_unknown.jsonl`.
