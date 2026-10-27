---
id: arch-clean-dependency-rule
title: Clean Architecture — la règle de dépendance
tags: [clean-architecture, design-principle]
status: verified
updated: 2026-10-26
sources: [https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html]
links: [arch-clean-flutter-layers, arch-dto-mappers, arch-fsd-layers]
---
# « Les dépendances de code source ne pointent que vers l'intérieur »

Clean Architecture (R. C. Martin, 2012) organise le code en cercles concentriques. Rien dans un cercle intérieur ne doit **nommer** quoi que ce soit d'un cercle extérieur.

Les cercles, de l'intérieur vers l'extérieur :
1. **Entities** : règles métier générales, les plus stables.
2. **Use Cases** : règles applicatives, qui orchestrent les entités.
3. **Interface Adapters** : conversion de format (controllers, presenters, gateways).
4. **Frameworks & Drivers** : DB, web, UI. Du code de glue.

**Franchir une frontière :**
- seules des structures de données simples (DTO) traversent ;
- jamais une entité ni une ligne de DB ;
- quand l'intérieur doit appeler l'extérieur, on **inverse la dépendance** : une interface est définie à l'intérieur et implémentée à l'extérieur.

**Parallèle avec FSD (opinion) :**
- FSD applique la même idée sur l'axe métier : un import ne va que vers une couche strictement inférieure (`arch-fsd-layers`).
- Clean l'applique sur l'axe technique : domain ← data et domain ← presentation.
- Les deux se combinent (`arch-clean-fsd-combo`).
