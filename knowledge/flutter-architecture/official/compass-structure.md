---
id: arch-compass-structure
title: Structure de paquets de l'app exemple Compass
tags: [flutter, architecture, folder-structure, official]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/app-architecture/case-study, https://github.com/flutter/samples/tree/main/compass_app]
links: [arch-official-layers, arch-recommended-structure]
---
# Compass app : UI rangée par feature, Data rangée par type

L'étude de cas officielle combine deux rangements :
- `ui/` est rangé **par feature**, car une view et son view model forment une feature.
- `data/` est rangé **par type**, car les repositories et services sont partagés entre features.

```
lib/
├── ui/
│   ├── core/{ui,themes}/          # widgets partagés, thème
│   └── <feature>/{view_models,widgets}/   # <feature>_screen.dart
├── domain/models/                 # types partagés UI + data
├── data/{repositories,services,model}/    # model = modèles API
├── config/  utils/  routing/
├── main.dart  main_development.dart  main_staging.dart
test/        # même arborescence que lib/
testing/     # « une version de l'app qu'on ne livre pas » : fakes, utilitaires
```

**À retenir :**
- Un point d'entrée par environnement : une variante `main_*.dart` par environnement.
- Le dossier `testing/` contient les fakes réutilisables. C'est cohérent avec la recommandation « faire des fakes ».
- Il n'y a pas de dossier `usecases/` : la couche domaine est optionnelle.

⚠️ Pièges
- Cette structure est **mono-package** et horizontale. Au-delà de quelques features, `data/` devient un fourre-tout sans frontière vérifiable. → Voir `arch-clean-fsd-combo` pour un découpage vertical en packages.
