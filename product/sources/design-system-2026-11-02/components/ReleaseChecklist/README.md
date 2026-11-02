# ReleaseChecklist
Tableau go/no-go : critère, seuil, valeur courante, référence, statut, et un verdict.

- Colonnes stables : critère · seuil · valeur (référence en `ink-muted`) · badge. Les lignes bloquantes portent un liseré `nogo` à gauche intérieur.
- Verdict `gc-badge--lg` à côté du titre ; compteur « 2 bloquants / 3 » à droite.
- Lignes révélées en cascade (`gc-row`, 180 ms d'écart) quand l'agent les écrit.
