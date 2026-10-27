---
id: test-very-good-analysis
title: Lints stricts — very_good_analysis
tags: [lint, analysis, very_good_analysis, ci]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/very_good_analysis]
links: [test-coverage-ci, test-tdd-red-green-refactor, arch-analyzer-plugins]
---
# Lints stricts partagés : very_good_analysis

Version observée le 2026-10-26 : **very_good_analysis 11.0.0**, publiée le 2026-09-03.

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml   # suit la dernière version
# ou figé : package:very_good_analysis/analysis_options.11.0.0.yaml
analyzer:
  exclude: ["**/*.g.dart", "**/*.freezed.dart"]
linter:
  rules:
    public_member_api_docs: false   # app, pas une lib publique
```

## Désactivation
- **Projet entier :** `rule: false` sous `linter: rules:`.
- **Fichier :** `// ignore_for_file: rule`.
- **Ligne :** `// ignore: rule` placé au-dessus de la ligne.

## Recommandations (opinion)
- Une majeure de very_good_analysis peut ajouter des lints : en CI, inclure le **fichier versionné**, et monter de version via une PR dédiée.
- Garder `public_member_api_docs` dans les packages partagés (`voice_test_kit`, contrats d'agents) et le couper dans l'app.
- Les tests sont analysés aussi : les lints imposent des types explicites, ce qui aide la lisibilité des fakes.

## ⚠️ Pièges
- L'option `analyzer: exclude` ci-dessus est de la config Dart standard, pas propre à very_good_analysis.
- Le fichier versionné doit exister dans la version installée : la 11.0.0 embarque `analysis_options.<x.y.z>.yaml` de 1.0.0 à 11.0.0, et `analysis_options.yaml` y inclut `analysis_options.11.0.0.yaml`.
