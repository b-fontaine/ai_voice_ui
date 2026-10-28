---
id: ds-widgetbook-publish-web
title: Widgetbook 4 — publier le catalogue web sans Cloud
tags: [widgetbook, web, hosting, deep-links, design-system]
status: sourced
updated: 2026-10-28
sources: [https://docs.widgetbook.io/~v4/sharing/hosting, https://docs.widgetbook.io/~v4/sharing/embedding, https://docs.widgetbook.io/~v4/configure/initial-route, https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz, https://github.com/widgetbook/widgetbook/issues/1797, https://github.com/flutter/flutter/blob/stable/packages/flutter_tools/lib/src/runner/flutter_command.dart, https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages, https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages, https://github.com/orgs/community/discussions/13309, https://firebase.google.com/docs/hosting/full-config, https://firebase.google.com/docs/hosting/manage-hosting-resources, https://github.com/FirebaseExtended/action-hosting-deploy]
links: [adr-0006-ds-no-widgetbook-cloud, ds-widgetbook-visual-review-ci, perf-web-wasm-build, perf-web-coop-coep, ds-widgetbook-4-setup]
---
# Le catalogue v4 auto-hébergé est un simple dossier `build/web/` statique

Sans Cloud ([[adr-0006-ds-no-widgetbook-cloud]]), la doc v4 dit de servir le `build/web/` produit par `flutter build web` depuis n'importe quel hébergeur statique. Build, hébergement et CI de publication sont à notre charge. Infos au 2026-10-28, widgetbook 4.0.0-beta.14.

## Build
- `--base-href /<repo>/` réécrit le `<base href>` de `web/index.html` ; la valeur commence et finit par `/`. Source : aide de la CLI (Flutter 3.47.8). La doc Flutter ne donne pas de recette GitHub Pages.
- `--wasm` et ses replis : [[perf-web-wasm-build]]. Le multi-thread skwasm exige COOP/COEP : [[perf-web-coop-coep]].

## Hébergement
- **GitHub Pages :** site projet à `<owner>.github.io/<repo>`, un seul site par dépôt.
  - En-têtes personnalisés (COOP/COEP) impossibles d'après la discussion communautaire #13309 (« No ETA », 2023-07-10) ; la doc officielle ne le dit pas. Un build `--wasm` y tourne donc sans multi-thread. Le comportement exact (mono-thread ou repli CanvasKit) et le contournement coi-serviceworker ne sont pas vérifiés.
  - Déploiement par workflow : permissions `pages: write` et `id-token: write`, environnement `github-pages`. Versions contestées : la doc montre `configure-pages@v5`, `upload-pages-artifact@v4`, `deploy-pages@v4`, mais des majeures v6/v5/v5 sont sorties en 2026.
  - Preview par PR : impossible en déploiement par workflow (chaque déploiement remplace le site). En déploiement par branche, `pr-preview-action` publie chaque PR dans un sous-dossier. Non vérifié sur source primaire.
- **Firebase Hosting :** `firebase.json` accepte `"headers": [{"source": "**", "headers": [{"key": ..., "value": ...}]}]`, d'où COOP/COEP et skwasm multi-thread.
  - Preview channels : `firebase hosting:channel:deploy CHANNEL_ID` → `SITE_ID--CHANNEL_ID-RANDOM_HASH.web.app`. Expiration par défaut 7 jours, au plus 30 jours après le déploiement (`--expires 12h|7d|2w`).
  - `FirebaseExtended/action-hosting-deploy@v0` (installée par `firebase init hosting:github`) crée un canal par PR si `channelId` est vide. Avec `repoToken`, elle commente la PR avec l'URL (`disableComment` pour couper). Sorties : `urls`, `details_url`.

## Liens profonds (v4)
- Stratégie **hash** : `/#/?path=<chemin/story>`. `&preview` masque toute l'UI Widgetbook. `&panels=args,addons,navigation` choisit les panneaux et est ignoré avec `preview`. La valeur `knobs` de la 3.x devient `args` (déduit de la doc et de l'enum `LayoutPanel`, pas d'une note de migration).
- Clés réservées (code beta.14, `AppRouteConfig.reservedKeys`) : `path`, `preview`, `q`, `panels`. Tout paramètre dont la valeur a la forme `{clé:valeur,...}` est lu comme un groupe : nom de l'Arg, ou `slugify(nom)` pour un addon ; `??` = groupe nul. Une URL d'état complet est donc partageable. Ce format vient d'API `@internal` non documentées, qui peuvent changer avant la 4.0 stable.
- Page d'accueil : `Config(initialRoute: '?path=...')` (URL à copier depuis l'app web lancée). `Config.foldersExpandedByDefault` (beta.14) : arbre replié au démarrage, sauf les ancêtres du nœud ouvert par lien profond.
- La doc v4 recommande de partager une story par « Deep link plus preview ».

## ⚠️ Pièges
- Issue ouverte #1797 : la stratégie d'URL **path** n'est pas supportée ; rechargement ou lien profond renvoient à l'accueil (`flutter run -d chrome` comme `flutter build web`). Rester en hash (opinion).
- Pour une démo en Wasm multi-thread, préférer Firebase Hosting à GitHub Pages (opinion).
