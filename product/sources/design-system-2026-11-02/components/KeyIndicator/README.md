# KeyIndicator
Le chiffre héros d'un écran, avec sa jauge et ses deltas nommés.

- `gc-kpi__value` (kpi-xl, mono tabulaire) avec `data-count` pour le compteur animé qui descend de 100 vers la valeur.
- Jauge `gc-gauge` : échelle 99–100 %, `gc-gauge__mark` = seuil, `gc-gauge__ref` = version précédente.
- Chaque delta dit **par rapport à quoi** (`vs seuil`, `vs 3.3`). Un « −0,54 pt » nu est illisible.
- Fourni par le consommateur : la valeur, le seuil, la référence, l'échelle de la jauge.
