# AgentRail
Les agents A2A et leur état : orchestrateur, en veille, au travail, terminé.

- **Ordre fixe** d'un acte à l'autre (Orchestrateur, Qualité, Voix du client, Livraison). Dans les captures d'origine, Livraison change de colonne entre les actes : l'œil le perd.
- États : `is-orch` (plasma), `is-work` (signal, barre indéterminée), `is-done` (✓ + composant produit + durée).
- Afficher la durée : c'est la preuve que les agents travaillent en parallèle.
