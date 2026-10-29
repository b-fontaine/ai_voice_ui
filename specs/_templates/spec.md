# NNN — <Fonctionnalité>

> **En bref.** <2 lignes : ce que l'utilisateur (speaker ou public) peut faire à la fin.>

- **Jalon** : J<n> (`product/roadmap/roadmap.md`)
- **Exigences visées** : FR-xx, NFR-xx, RG-xx (définies dans `product/functional/`)
- **Décisions applicables** : pdr-xxxx, adr-xxxx
- **Hors périmètre** : <ce que cette fonctionnalité ne fait pas>

## Scénarios (Gherkin)
<!-- Renvoyer aux scénarios existants de product/functional/features/*.feature (S-xx).
     Un scénario nouveau est d'abord ajouté à product/ (skill product-curate), puis cité ici. -->
- S-xx — <titre> (`product/functional/features/<fichier>.feature`)

## Critères d'acceptation
- [ ] Scénarios ci-dessus automatisés et verts
- [ ] Tests unitaires des unités nouvelles
- [ ] `tools/loop/gate.sh --full` vert
- [ ] Revue d'architecte : CONFORME (ou refactorisations appliquées)
- [ ] <critère mesurable propre à la fonctionnalité, ex. squelette < 1,5 s sur le journal>

## Questions ouvertes
<!-- Arbitrage du porteur → product/roadmap/open-questions.md (Q-xx) ; la fonctionnalité continue sur ce qui n'en dépend pas. -->
