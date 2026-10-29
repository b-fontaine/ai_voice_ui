@AGENTS.md

# Spécifique à Claude Code

- Avant toute tâche (code, plan, revue, question technique), invoquer le skill **`kb-lookup`**. À défaut, suivre la procédure du § 1 de AGENTS.md.
- Pour ajouter, corriger ou réorganiser des connaissances, utiliser le skill **`kb-curate`**.
- Avant toute tâche qui touche le produit Genesis Canvas (fonctionnel, architecture produit, roadmap, décision, ou code d'une fonctionnalité), invoquer **aussi** le skill **`product-lookup`**. À défaut, suivre la procédure du § 1 bis de AGENTS.md.
- Pour ajouter, corriger ou réorganiser un document de `product/` (exigence, règle, écran, catalogue, question ouverte, architecture, roadmap…), utiliser le skill **`product-curate`**.
- Pour proposer, accepter, remplacer, reconfirmer ou abandonner une décision produit (`pdr-*`), ou clore une question `Q-xx`, utiliser le skill **`product-decide`**. Une décision réutilisable sur d'autres projets passe par **`kb-curate`** (ADR).
- Déléguer à l'agent **`product-steward`** les mises à jour documentaires transverses (plusieurs zones de `product/`, propagation d'une décision ou d'une nouvelle source). Pour propager une décision, le message de délégation **cite mot pour mot** la parole du porteur (date, canal) ; sans cette citation, l'agent ne crée au plus qu'une PDR `proposée`, sauf décision contrainte (`product-decide` § 0 bis). Une simple consultation reste dans le contexte courant (`product-lookup`).
