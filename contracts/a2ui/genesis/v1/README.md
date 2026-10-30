# Contrat du catalogue `genesis` (v1)

Ces fixtures sont le **contrat exécutable** entre les agents A2A, l'orchestrateur et le client Flutter (spec 006, amendement A3). Les exemples d'écrans de l'acte 1 servent aussi d'exemples guidés au sens de pdr-0023.

- `catalog.json` : les 4 composants du catalogue (`components` est la valeur de `A2UI_COMPONENTS`), propriétés admises (`id`, `component`, `data`), liaison `data = {"path": "/<surface>"}` et forme du data model de chaque surface. Les codes de statut sont fermés (`ok|risk|blocking`) et accompagnés d'un libellé séparé ; aucune couleur ne dépend d'un libellé français (RG-09).
- `examples/act1-*.jsonl` : une ligne JSON par message A2UI v0.9, dans l'ordre des trois temps (RG-02) : `createSurface`, `updateComponents` (composant `root`, donnée absente), `updateDataModel` (chemin racine de la surface, valeur complète). Valeurs : `product/functional/dataset.md`, acte 1.

## Remplacement de `${CATALOG_ID}`

Le texte `${CATALOG_ID}` est un placeholder (l'identifiant réel est provisoire, Q-44, et vient de la configuration `A2UI_CATALOG_ID`). Tout consommateur le remplace, **textuellement et partout**, par l'identifiant configuré avant de lire une ligne ou d'attendre une égalité.

Les fixtures ne doivent jamais contenir d'identifiant réel.
