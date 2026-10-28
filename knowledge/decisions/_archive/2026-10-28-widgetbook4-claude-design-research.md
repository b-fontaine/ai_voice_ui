# Archive brute — Widgetbook 4.0 bêta, Claude Design, publication sans Cloud (2026-10-28)

Workflow ds-research-pass3 (wf_9eec30cd-bf3) : 5 sujets, 2 vérificateurs adverses (exactitude, actualité). Sert les ADR 0006 à 0008.

## catalog-no-cloud

## KEPT (26)
- La doc Widgetbook 4 existe sous le préfixe https://docs.widgetbook.io/~v4/ (avec un llms.txt à https://docs.widgetbook.io/~v4/llms.txt) ; https://docs.widgetbook.io/v4 renvoie 404. Sur pub.dev, la dernière version stable de widgetbook est 3.25.0 et la dernière préversion est 4.0.0-beta.14 (vérifié le 2026-10-28 via https://pub.dev/api/packages/widgetbook).
  <https://docs.widgetbook.io/~v4/llms.txt>
- En v4, l'auto-hébergement consiste à servir le dossier build/web/ produit par `flutter build web` depuis n'importe quel hébergeur statique (GitHub Pages cité). Le build, l'hébergement et la CI de publication sont à notre charge.
  <https://docs.widgetbook.io/~v4/sharing/hosting>
- Sans Widgetbook Cloud, rien ne compare les snapshots v4 (build/.widgetbook) d'un commit à l'autre. La détection de régression visuelle repose alors sur des golden tests écrits par widget, avec des baselines commitées et mises à jour via `--update-goldens`.
  <https://docs.widgetbook.io/~v4/sharing/hosting>
- En auto-hébergé, la doc v4 indique qu'on partage une story par « Deep link plus preview ». La mise à jour d'une baseline se fait par « Rerun with `--update-goldens` and commit the images ».
  <https://docs.widgetbook.io/~v4/sharing/hosting>
- Les deep links Widgetbook v4 utilisent la stratégie hash : `/#/?path=<chemin/story>`. `&preview` masque toute l'UI de Widgetbook. `&panels=args,addons,navigation` choisit les panneaux affichés et est ignoré si `preview` est présent. En v4, la valeur de panneau `knobs` de la 3.x devient `args`.
  <https://docs.widgetbook.io/~v4/sharing/embedding>
  ~ Nuance: the 'knobs' to 'args' rename is inferred from comparing the v3 and v4 docs and from the LayoutPanel enum (navigation, addons, args). The v4 docs do not state it as a migration note.
- Dans le code de widgetbook 4.0.0-beta.14, les clés d'URL réservées sont exactement path, preview, q (recherche) et panels (AppRouteConfig.reservedKeys). Tout autre paramètre dont la valeur a la forme `{clé:valeur,...}` est lu comme un QueryGroup, ce qui sert à encoder les valeurs d'args et d'addons dans l'URL.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz>
  ~ Precision: queryGroups does not filter out reserved keys. Any parameter whose value matches QueryGroup.pattern (^\??\{.*\}$|^\?\?$) is parsed as a group.
  ~ Small nuance: queryGroups does not explicitly filter out the reserved keys. It keeps every parameter whose value matches QueryGroup.pattern (^\??\{.*\}$|^\?\?$). The reserved keys drop out only because their values do not match that pattern.
- En 4.0.0-beta.14, le nom de paramètre d'URL d'un Arg est son nom (`groupName => name`), et celui d'un addon est `slugify(name)`. Les valeurs sont sérialisées en `{key:value,...}` avec Uri.encodeComponent sur la clé et la valeur. Le préfixe `??` marque un groupe annulé (null). Une URL d'état complet (args + addons) est donc partageable.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz>
- En Widgetbook 3.x (doc courante), les deep links ont la forme `/#/?path=...&preview` et `&panels=knobs`, `knobs,addons` ou `navigation`.
  <https://docs.widgetbook.io/essentials/embedding>
- En v4, la page d'accueil se fixe avec `Config(initialRoute: '?path=...')` (en 3.x, c'était un paramètre du constructeur `Widgetbook`). La doc conseille de copier l'URL depuis l'app web en cours d'exécution.
  <https://docs.widgetbook.io/~v4/configure/initial-route>
  Q: final config = Config(
       // ...
       initialRoute: '?path=introduction/home-story',
     );
- widgetbook 4.0.0-beta.14 ajoute `Config.foldersExpandedByDefault`. L'arbre de navigation démarre alors replié, mais les ancêtres d'un nœud ouvert par deep link sont dépliés au démarrage.
  <https://pub.dev/packages/widgetbook/versions/4.0.0-beta.14/changelog>
- Les scénarios v4 s'exécutent avec `flutter test` via `test/widgetbook_test.dart`, qui appelle `await testWidgetbook(config);` (import `package:widgetbook/test.dart`). Chaque scénario écrit un PNG et un JSON de métadonnées dans build/.widgetbook/<Component>/<Story>/<Scenario>.png. Ce dossier peut être publié tel quel comme artefact CI.
  <https://docs.widgetbook.io/~v4/testing/run-scenarios>
  ~ Nuance: 'can be published as-is as a CI artifact' is our own inference; the page does not say it.
  ~ Nuance for publishing as a CI artifact: actions/upload-artifact excludes hidden files by default (include-hidden-files: false), and that includes 'files within folders beginning with .'. To publish build/.widgetbook you must set include-hidden-files: true.
- En v4, les violations d'accessibilité ne font pas échouer `flutter test`. Elles sont écrites dans le champ `violations` du JSON de chaque scénario, que la CI doit lire elle-même si on veut un blocage.
  <https://docs.widgetbook.io/~v4/genui/testing>
- La doc v4 a une page GenUI dédiée (« Test the Catalog, Not the Screen »). On teste chaque widget du catalogue par des scénarios aux bornes du schéma, et non les écrans générés par le modèle, qui changent à chaque exécution.
  <https://docs.widgetbook.io/~v4/genui/testing>
- `excludeFromTests: true` (ajouté en 4.0.0-beta.10) peut se poser sur un `_Story` ou un `_Scenario`. L'élément est alors sauté par testWidgetbook, sans snapshot, mais reste visible dans le catalogue web.
  <https://docs.widgetbook.io/~v4/testing/run-scenarios>
- Dans les tests, le réseau est inaccessible. Les polices google_fonts doivent donc être embarquées en assets avec le fetch runtime désactivé, sinon le texte apparaît en rectangles noirs dans les snapshots.
  <https://docs.widgetbook.io/~v4/sharing/fonts>
  ~ Nuance: the page does not link google_fonts directly to black rectangles. It attributes the rectangles to an unregistered font family in the test font manifest; this is the likely result, not a quote.
- `flutter build web --base-href` réécrit l'attribut href de la balise <base> de web/index.html (placeholder $FLUTTER_BASE_HREF). La valeur doit commencer et finir par « / », par exemple `--base-href /<repo>/` pour un site projet GitHub Pages servi à <owner>.github.io/<repositoryname>. Vérifié avec `flutter build web -h` sur Flutter 3.47.8.
  <https://github.com/flutter/flutter/blob/stable/packages/flutter_tools/lib/src/runner/flutter_command.dart>
- L'URL par défaut d'un site projet GitHub Pages est http(s)://<owner>.github.io/<repositoryname>, avec au plus un site Pages par dépôt. Un seul déploiement Pages ne permet donc pas d'avoir une preview par PR.
  <https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages>
  ~ Nuance: 'no per-PR preview' is our inference from the one-site limit, not a statement on the page.
  ~ Nuance: the conclusion 'no preview per PR' holds for the workflow (artifact) deployment, where each deploy replaces the whole site. With a branch-based deployment, actions such as pr-preview-action publish each PR in a subfolder of the single site, so PR previews are possible, at the cost of extra plumbing.
- `flutter build web --wasm` compile en dart2wasm + skwasm, avec repli automatique sur dart2js + CanvasKit si WasmGC n'est pas détecté. Chrome < 137 se replie aussi. Safari (wasmAllowList.webkit) et Firefox (wasmAllowList.gecko) sont désactivés par défaut.
  <https://docs.flutter.dev/platform-integration/web/wasm>
  ~ Precision: the docs describe the default behavior for Flutter 3.50 (local Flutter is 3.47.8). Fallback needs WasmGC plus JS String Builtins and Phase 4 Exception Handling, not just WasmGC.
  ~ Detail: Safari 26.2+ and Firefox 147+ can be enabled through wasmAllowList { webkit: true } / { gecko: true }. The docs describe the behavior of Flutter 3.50.
- Le rendu Wasm multi-thread exige que le serveur envoie `Cross-Origin-Embedder-Policy: credentialless` (ou `require-corp`) et `Cross-Origin-Opener-Policy: same-origin`. Sans ces en-têtes, l'app ne tourne pas en multi-thread.
  <https://docs.flutter.dev/platform-integration/web/wasm>
- GitHub Pages ne permet pas de définir des en-têtes HTTP personnalisés (COOP/COEP). La discussion communautaire #13309 est toujours « Unanswered ». Le 2023-07-10, un intervenant y répond « No ETA ». Sur Pages, un build --wasm fonctionnera donc sans multi-thread.
  <https://github.com/orgs/community/discussions/13309>
- Firebase Hosting permet de déclarer des en-têtes dans firebase.json via `"headers": [{"source": <glob>, "headers": [{"key": ..., "value": ...}]}]`. On peut ainsi poser COOP/COEP sur `**` pour activer skwasm multi-thread.
  <https://firebase.google.com/docs/hosting/full-config>
- Les preview channels Firebase se déploient avec `firebase hosting:channel:deploy CHANNEL_ID`, à l'URL PROJECT_ID--CHANNEL_ID-RANDOM_HASH.web.app. Par défaut un canal expire 7 jours après sa création, au maximum 30 jours (`--expires 7d|12h|2w`).
  <https://firebase.google.com/docs/hosting/manage-hosting-resources>
  ~ The documented URL is SITE_ID--CHANNEL_ID-RANDOM_HASH.web.app, not PROJECT_ID (the default site ID is often the project ID). The 30-day maximum counts from the date of deploy.
  ~ Nuances: the official URL format is SITE_ID--CHANNEL_ID-RANDOM_HASH.web.app (SITE_ID, which equals PROJECT_ID only for the default site). The 30-day maximum counts 'from the date of deploy', not from creation.
- L'action GitHub FirebaseExtended/action-hosting-deploy@v0, installée par `firebase init hosting:github`, crée un preview channel par PR si `channelId` est vide. Elle commente la PR avec l'URL de preview quand `repoToken` est fourni (désactivable par `disableComment`) et expose les sorties `urls` et `details_url`.
  <https://github.com/FirebaseExtended/action-hosting-deploy>
- Quand un golden échoue, le comparateur Flutter par défaut (LocalFileComparator) écrit dans un dossier `failures` placé à côté du golden quatre images : testName_masterImage.png, testName_testImage.png, testName_isolatedDiff.png et testName_maskedDiff.png. C'est ce dossier qu'on publie en artefact CI.
  <https://api.flutter.dev/flutter/flutter_test/LocalFileComparator-class.html>
- alchemist 0.14.1 (dernière version sur pub.dev) écrit les goldens CI dans goldens/ci/, à côté du fichier de test, et se configure via AlchemistConfig (PlatformGoldensConfig / CiGoldensConfig). Les baselines se régénèrent avec `flutter test --update-goldens`.
  <https://pub.dev/packages/alchemist>
- actions/upload-artifact en est à la v7. Ses entrées sont `name`, `path` (fichier, dossier ou wildcard), `if-no-files-found` (warn par défaut) et `retention-days` (1 à 90). Sa sortie `artifact-url` ne fonctionne que pour un utilisateur connecté, et peut être recopiée dans un commentaire de PR.
  <https://github.com/actions/upload-artifact>
  ~ The input list is incomplete: compression-level, overwrite and others also exist. The retention-days maximum of 90 can be changed in repository settings.
  ~ The list of inputs is incomplete: there are also compression-level, overwrite, include-hidden-files (default false, which matters for build/.widgetbook) and archive. retention-days can go above 90 if the repository settings allow it.
## CONTESTED (1)
- Le déploiement GitHub Pages par workflow utilise actions/configure-pages@v5, actions/upload-pages-artifact@v4 et actions/deploy-pages@v4. Le job de déploiement exige les permissions `pages: write` et `id-token: write`. L'environnement par défaut est `github-pages`.
  <https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages>
  Q: uses: actions/deploy-pages@v4
  ~ The GitHub docs page (using-custom-workflows) still shows configure-pages@v5, upload-pages-artifact@v4 and deploy-pages@v4. Newer majors have been released: actions/configure-pages v6.0.0 (2026-03-25), actions/upload-pages-artifact v5.0.0 (2026-04-10) and actions/deploy-pages v5.0.0 (2026-03-25), now v5.0.1 (2026-09-01). Recommend v6/v5/v5. The permissions pages: write and id-token: write and the 
  ! The GitHub API releases/latest for each repo shows majors newer than the ones in the claim, so the versions given are out of date as of 2026-10-28.
## KILLED (0)
## GAPS
- Aucune page de la doc v4 ne documente l'encodage des args dans l'URL. Le format {clé:valeur} et le nom de paramètre égal au nom de l'Arg viennent de la lecture du code source de 4.0.0-beta.14 (lib/src/core/routing/query_group.dart, framework/arg.dart). Ce sont des API internes (@internal) qui peuvent changer avant la 4.0 stable.
- La doc Flutter (deployment/web, url-strategies) ne donne pas de recette GitHub Pages. L'option --base-href n'est sourcée que par l'aide de la CLI (flutter_command.dart, Flutter 3.47.8 local).
- La doc GitHub officielle ne dit pas explicitement que les en-têtes personnalisés sont impossibles sur Pages. La seule source est la discussion communautaire #13309, et le statut « staff » de l'intervenant n'est pas affiché. Le contournement par coi-serviceworker n'a pas été vérifié.
- Le comportement exact de skwasm sans COOP/COEP (mono-thread ou repli sur CanvasKit) n'est pas décrit sur docs.flutter.dev/platform-integration/web/wasm.
- Previews par PR sur GitHub Pages, ou via des environnements GitHub par PR : aucune source primaire trouvée. GitHub Pages n'autorise qu'un site par dépôt.
- La doc alchemist sur pub.dev ne mentionne pas le dossier failures/. Le dossier et les noms de fichiers viennent du LocalFileComparator de Flutter, qu'alchemist utilise vraisemblablement, sans que cela ait été vérifié dans son code.
- Aucun exemple officiel `if: failure()` combiné à upload-artifact n'a été lu. La CI pr-comment (par exemple marocchino/sticky-pull-request-comment ou gh pr comment) n'a pas été vérifiée.
- La v4 ne produit aucun diff de snapshots en local : build/.widgetbook ne contient que les images courantes. Un diff sans Cloud demande donc soit des goldens classiques (alchemist/matchesGoldenFile), soit un script de comparaison maison. Aucun outil officiel n'a été trouvé.
- Non couvert par cette recherche : Claude Design, Style Dictionary et material_ui.

## claude-design

## KEPT (26)
- Anthropic a annoncé Claude Design le 17 avril 2026. C'est un produit Anthropic Labs, lancé en research preview et propulsé par Claude Opus 4.7. Il sert à produire des designs, des prototypes, des slides et des one-pagers.
  <https://www.anthropic.com/news/claude-design-anthropic-labs>
- À son lancement en avril 2026, Claude Design était réservé aux abonnés Pro, Max, Team et Enterprise. Sur Enterprise, il était désactivé par défaut et l'admin devait l'activer.
  <https://www.anthropic.com/news/claude-design-anthropic-labs>
  ~ This describes the situation at launch. It is now outdated: see [2], which says all plans have it, Free included.
- Le centre d'aide indique aujourd'hui que Claude Design est disponible sur les plans Free, Pro, Max, Team et Enterprise, activé par défaut. Sur Enterprise, l'activation par défaut date du 15 octobre 2026.
  <https://support.claude.com/en/articles/14604416-get-started-with-claude-design>
  ~ Before October 15, 2026, Enterprise Owners could already turn it on themselves in Organization settings > Artifacts.
- Selon la page produit, Claude Design, Claude Slides et Claude Docs sont inclus dans tous les plans, Free compris.
  <https://claude.com/product/design>
- CONFIRMÉ : la version autonome de Claude Design (claude.ai/design) ferme le 14 décembre 2026. Elle reste accessible jusqu'à cette date. Ensuite, elle passe en lecture seule et on ne peut plus y créer de projet.
  <https://support.claude.com/en/articles/17440474-move-from-standalone-claude-design-to-claude>
- Ce qui change : « Claude Design now lives in Claude » signifie qu'un nouveau design, design system ou slide deck démarré dans Claude devient un artifact claude.ai. Il n'existe plus comme projet du site autonome.
  <https://support.claude.com/en/articles/17440474-move-from-standalone-claude-design-to-claude>
- Migration : une seule opération (« Move team design systems », sur la page Artifacts) déplace tous les design systems de l'organisation. Les chats et les commentaires ne migrent pas. Les liens publics des projets autonomes cesseront de fonctionner après la fermeture.
  <https://support.claude.com/en/articles/17440474-move-from-standalone-claude-design-to-claude>
  ~ Nuance: once 'Move to Claude' is available, an owner can also move a single design system, or an org owner can move all of them at once.
  ~ The article's slug now appears as 'migrate-from-standalone-claude-design-to-claude' in the Claude Code docs. The content is the same.
- Le changelog de Claude Code v2.1.302 (16 octobre 2026) a ajouté à /design-sync et /design-login l'avis de fermeture du site autonome. C'est la source de la notice affichée par l'outil.
  <https://code.claude.com/docs/en/changelog.md>
- /design-sync est une skill intégrée à Claude Code. Elle convertit le design system React d'un dépôt et l'envoie au site autonome claude.ai/design. Elle n'est donc utile que jusqu'au 14 décembre 2026.
  <https://code.claude.com/docs/en/commands.md>
- /design-sync exige une connexion à claude.ai, via /design-login si besoin. Il est indisponible sur Bedrock, Google Cloud Agent Platform, Microsoft Foundry et Claude Platform on AWS. Une première synchro vérifie chaque composant et peut durer plusieurs heures.
  <https://code.claude.com/docs/en/commands.md>
  ~ Nuance: it is also unavailable through a Claude apps gateway. The /design-login entry gives the sign-in, which is for the standalone site.
  ~ The command is also unavailable through a Claude apps gateway. It is available on the Anthropic API.
- L'outil DesignSync, qu'utilise la skill /design-sync, synchronise incrémentalement, un composant à la fois. La séquence est imposée : list/read, puis finalize_plan (qui renvoie un planId approuvé par l'utilisateur), puis write_files/delete_files.
  <claude-code://tool/DesignSync (description de l'outil intégré, session Claude Code locale du 2026-10-28)>
- Dans un projet design system, le panneau « Design System » construit son index de cartes à partir d'un commentaire en première ligne de chaque HTML de preview, `<!-- @dsCard group="…" -->`. L'auto-vérification de l'app compile ces marqueurs dans `_ds_manifest.json`. register_assets n'est plus qu'un mécanisme legacy.
  <claude-code://tool/DesignSync (description de l'outil intégré, session Claude Code locale du 2026-10-28)>
  ~ Nuance: register_assets is still advised for hand-authored projects without @dsCard markers.
- Le support d'aide recommande /design-sync uniquement quand le design system existe déjà en composants React. La skill lit directement les tokens et les composants.
  <https://support.claude.com/en/articles/14604397-set-up-your-design-system-in-claude-design>
  ~ Nuance: the article does not say 'only'. It recommends /design-sync when the system already exists as React components ('works best for product design systems in code') and lists other routes, such as chat and uploads.
- La page produit précise que la création d'un design system via Claude Code fonctionne le mieux pour des organisations ayant déjà un design system React. Aucun autre framework n'est cité, Flutter compris.
  <https://claude.com/product/design>
- Source tierce : /design-sync n'accepte qu'un package React avec un `dist/` publié, ou un Storybook. Vue, Angular et Svelte ne sont pas supportés. Une synchro écrit `.design-sync/config.json`, `NOTES.md`, `conventions.md` et `_ds_sync.json` (hashes de contenu).
  <https://wmedia.es/en/tips/claude-code-design-sync-your-components>
  ~ Per the source, _ds_sync.json is part of what gets uploaded, where it lets the next sync skip unchanged components. It is not one of the files written into the repo's .design-sync/ folder, which holds config.json, NOTES.md, conventions.md and the previews.
- Un design system peut être importé depuis un dépôt GitHub, des fichiers de design, des uploads bruts ou la base de code locale, et un projet peut en combiner plusieurs.
  <https://support.claude.com/en/articles/14604416-get-started-with-claude-design>
  Q: Bring in one or several design systems from a GitHub repo, design files, raw uploads, or your local codebase
  ~ The article mentions this in the context of the /design-sync command in Claude Code.
- Dans Claude, chaque design system devient un artifact utilisable dans n'importe quel chat, y compris dans Claude Code. Claude en extrait couleurs, typographie, composants, espacements et grilles.
  <https://support.claude.com/en/articles/14604397-set-up-your-design-system-in-claude-design>
  ~ Nuance: the article lists color palette, typography, components and layout patterns (spacing, grid systems, page structures) for a generated design system. The phrase 'Claude extracts colors, layout patterns, and typographic choices' is about slide decks and documents.
  ~ The help article frames layout as 'Spacing, grid systems, and page structures'.
- Un design system de type « Design System » stocke ses tokens dans `project/tokens.json`, qu'il réécrit en entier. Les fichiers `tokens.css` et `manifest.json` sont générés par la page. L'index du système est `project/design-system.json`.
  <https://claude.ai/artifact/5M7UeXXcx16TP3vzVFNDzd>
  ~ Nuance: the generated files also include the api/… cards. A clean-up or /design-sync may write the first tokens.css.
- Le format `tokens.json` de Claude Design n'est PAS du DTCG. Chaque famille (color, spacing, radius, shadow…) est une LISTE `{"tokens":[{"name","value","usage"}]}`, et les couleurs multi-thèmes s'écrivent `value: {"light":…, "dark":…}`. Une map DTCG `$value` est illisible par la page : la famille apparaît vide.
  <https://claude.ai/artifact/5M7UeXXcx16TP3vzVFNDzd>
  ~ Nuance: the type family has its own shape. A plain string value counts as the first theme's value.
- Contraintes du tokens.json : chaque nom doit respecter `[A-Za-z0-9][A-Za-z0-9_.-]{0,63}` (sans `/` ni espace) et rester unique. Les alias s'écrivent `"{other-token}"`. Les valeurs `var()`, `color-mix()` et les couleurs nommées sont rejetées.
  <https://claude.ai/artifact/5M7UeXXcx16TP3vzVFNDzd>
  ~ Nuance: uniqueness applies 'across every family but type'. An alias must point to a color token that exists. Rejected values are dropped, not errors.
  ~ Aliases must point to a color token that exists. An alias of a missing token, or of itself, is dropped.
- Les previews de composants d'un design system sont des documents HTML exécutés dans le navigateur, avec bundle.js, tokens.css et React 18 préchargés. Le rendu est donc web/React, pas Flutter.
  <https://claude.ai/artifact/5M7UeXXcx16TP3vzVFNDzd>
  ~ Nuance: React 18 is not always preloaded. Previews preload tokens.css, the fonts, bundle.css, the bundle and the libraries the index lists. react/react-dom 18 load from jsDelivr only when the index lists them, as in the default example. With no libraries, previews are static.
  ~ Previews preload tokens.css, the fonts, bundle.css, the bundle and whatever libraries the index lists. React 18 is preloaded when it is listed in libraries (that is the default example), not unconditionally.
- Le bouton « Export » d'un projet Claude Design propose PDF, PPTX, Google Slides et HTML autonome. Le handoff vers Claude Code se fait via « Send to local coding agent » ou « Send to Claude Code Web ».
  <https://support.claude.com/en/articles/14604416-get-started-with-claude-design>
  ~ The Export menu also offers 'Download as .zip' and sending to about 15 third-party tools (Canva, Miro, Vercel, and others).
- Le guide admin Team/Enterprise liste comme formats d'export les bundles HTML, PPTX, PDF et Google Slides, ainsi que le handoff vers Claude Code.
  <https://support.claude.com/en/articles/14604406-claude-design-admin-guide-for-team-and-enterprise-plans>
- Dans Claude Code (v2.1.265+), `/design <brief>` publie un canevas d'artboards éditables sous forme d'artifact Claude Design. L'édition se fait dans un navigateur desktop, et chaque artboard s'exporte en PNG ou PDF.
  <https://code.claude.com/docs/en/artifacts.md>
  ~ In Enterprise orgs, an Owner must turn on the Design template, which is in beta.
- La documentation des artifacts Claude Code conseille de consigner les design tokens (couleurs, typo, espacements) dans CLAUDE.md ou dans un fichier de thème du dépôt. La skill de design les lit en priorité sur ses propres choix.
  <https://code.claude.com/docs/en/artifacts.md>
- Le billet du 17 juin 2026 annonce des exports vers PDF, PowerPoint et HTML, l'envoi vers des apps connectées (Canva, Gamma, Vercel), et un rôle admin qui approuve un design system standard et en verrouille l'édition.
  <https://claude.com/blog/claude-design-stays-on-brand-for-daily-work>
  ~ Nuance: the connector list also includes Adobe, Base44, Lovable, Miro, Replit and Wix.
  ~ The post also has a September 2026 update. Its list of connectors also includes Adobe, Base44, Lovable, Miro, Replit and Wix.
## CONTESTED (0)
## KILLED (0)
## GAPS
- Aucune source officielle ne mentionne Flutter, ni d'export de code Flutter/Dart. Les seuls rendus documentés sont web : HTML, React 18 dans les previews, /design-sync limité à React. Conséquence (déduction, pas une source) : la chaîne visée doit traiter Claude Design comme outil de maquette et de référence de tokens. Il faut convertir le tokens.json au format liste vers du DTCG (ou maintenir le DTCG comme source de vérité et le convertir en liste pour Claude Design), puis passer par Style Dictionary pour générer le Dart/ThemeData. /design-sync ne peut pas synchroniser une bibliothèque de widgets Flutter.
- Aucun export officiel des tokens en JSON DTCG n'est documenté. Le seul format confirmé est le tokens.json propriétaire au format liste, lisible via un read d'artifact. Un téléchargement direct de tokens.json depuis l'UI n'a pas été vérifié.
- Pas d'export Figma confirmé par Anthropic. L'import de « Figma files » est cité, mais le mécanisme n'est pas décrit.
- Le contenu exact du bundle de handoff vers Claude Code (HTML/CSS/JS ? React ?) n'est pas détaillé dans les sources officielles lues.
- L'export .zip et la liste exacte des « partner apps » du menu Export n'ont pas été vérifiés mot à mot. Les sources divergent : Canva/Gamma/Vercel dans le blog ; Adobe, Canva, Gamma, Lovable, Miro, Replit, Vercel et Wix sur la page produit.
- Après le 14 décembre 2026, on ne sait pas si /design-sync visera les artifacts Design System dans Claude : la doc actuelle dit qu'il envoie au site autonome. Aucune annonce de remplacement n'a été trouvée.
- Les références `artifact-type/reference/from-code.md` et `format.md` du type Design System n'ont pas été lues en détail : grammaire complète des tokens et procédure depuis du code.
- La date de sortie exacte de /design-sync (annoncée vers le 17 juin 2026) n'apparaît pas dans le changelog Claude Code consulté.
- Les affirmations sourcées « claude-code://tool/DesignSync » viennent de la description de l'outil intégré dans la session locale. Ce n'est pas une page web publique.

## wb4-api

## KEPT (28)
- La dernière préversion v4 de widgetbook est 4.0.0-beta.14, publiée sur pub.dev le 2026-09-11 ; elle exige Dart >=3.10.0 <4.0.0 et Flutter >=3.38.0. Le tag `latest` stable de pub.dev reste 3.25.0, donc il faut épingler explicitement `widgetbook: ^4.0.0-beta.14` (ou `4.0.0-beta.14`).
  <https://pub.dev/api/packages/widgetbook>
- Depuis 4.0.0-alpha.5, `widgetbook_generator` et `widgetbook_test` sont fusionnés dans le package `widgetbook`. En v4, il ne faut donc PAS ajouter `widgetbook_generator` (sa dernière v4 est la 4.0.0-alpha.4, de nov. 2025, obsolète), ni `widgetbook_test` (4.0.0-alpha.3), ni `widgetbook_annotation` (aucune version 4.x, la dernière est 3.11.0).
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/CHANGELOG.md>
- Le générateur de code est embarqué dans widgetbook 4.0.0-beta.14 via son build.yaml (builders `story_builder`, `components_builder` et `telemetry`, en auto_apply: dependents). Il suffit d'ajouter `build_runner` en dev_dependency. L'exemple officiel désactive la télémétrie avec `widgetbook:telemetry: enabled: false` dans build.yaml.
  <https://github.com/widgetbook/widgetbook/blob/v4/examples/full_example/build.yaml>
  Q: targets:
       $default:
         builders:
           widgetbook:telemetry:
             enabled: false
  ~ Nuance : dans packages/widgetbook/build.yaml, story_builder et components_builder sont en auto_apply: dependents, mais telemetry est en auto_apply: root_package (build_to: cache).
  ~ Nuance : `story_builder` et `components_builder` sont en auto_apply: dependents, mais `telemetry` est en auto_apply: root_package (build_to: cache).
- Le pubspec de l'exemple officiel full_example (branche v4) cible exactement notre stack : `sdk: ^3.13.0`, `flutter: ^3.47.0`, `widgetbook: ^4.0.0-beta.14` et, en dev, `build_runner: ^2.10.1`.
  <https://github.com/widgetbook/widgetbook/blob/v4/examples/full_example/pubspec.yaml>
  Q: environment:
       sdk: ^3.13.0
       flutter: ^3.47.0
     
     dependencies:
       flutter:
         sdk: flutter
       widgetbook: ^4.0.0-beta.14
     
     dev_dependencies:
       build_runner: ^2.10.1
- widgetbook_cli 4.0.0-beta.14 (publié le 2026-09-11) exige Dart >=3.11.0 et a le même numéro de version que widgetbook. La doc v4 l'installe avec `dart pub global activate widgetbook_cli 4.0.0-beta.14`, puis `widgetbook init` (commande marquée expérimentale ; options `--package`, `--output`, `--empty`).
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/quick-start.mdx>
  Q: dart pub global activate widgetbook_cli {{ versions.cli }}
     widgetbook init
  ~ Nuance : quick-start.mdx écrit `widgetbook_cli {{ versions.cli }}` (un placeholder) et non la version littérale. Le caractère expérimental et les options --package, --output et --empty viennent du code source (commands/init.dart), pas de la doc.
  ~ Nuance : la doc écrit `{{ versions.cli }}` et non `4.0.0-beta.14` en dur. Le caractère « expérimental » vient d'un logger.warn dans init.dart et n'a pas été vérifié mot pour mot.
- `widgetbook init` génère trois fichiers : `lib/main.dart`, qui appelle `runWidgetbook(config)` ; `lib/widgetbook.config.dart`, qui déclare `final config = Config(components: components, addons: [...])` en important `components.g.dart` ; et `test/widgetbook_test.dart`, qui appelle `await testWidgetbook(config)` en important `package:widgetbook/test.dart`.
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook_cli/lib/src/templates/main_template.dart>
  Q: import 'widgetbook.config.dart';
     
     void main() {
       runWidgetbook(config);
     }
  ~ Nuance : les fichiers sont créés dans un sous-dossier `widgetbook/` (projet créé par flutter create et nommé widgetbook_workspace). Sans --empty, init génère aussi des *.stories.dart pour les widgets existants.
  ~ Nuance : test_template importe `package:widgetbook_workspace/widgetbook.config.dart`, un nom de package codé en dur.
- En v4, il n'y a plus de widget `Widgetbook.material`. Le point d'entrée est la fonction `void runWidgetbook(Config config)`, qui lance `runApp(WidgetbookApp(config: config))`. Par défaut, `Config` utilise `appBuilder = materialAppBuilder` (un MaterialApp avec `home: Material(child: child)`).
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/runner.dart>
  Q: void runWidgetbook(Config config) {
       runApp(WidgetbookApp(config: config));
     }
- Paramètres nommés de `Config` en beta.14, avec leurs valeurs par défaut : initialRoute='/', components=const [], appBuilder=materialAppBuilder, home=const DefaultHomePage(), addons, integrations, lightTheme, darkTheme, themeMode=ThemeMode.system, header, scrollBehavior=const MaterialScrollBehavior(), scenarioConfig=const ScenarioConfig(), accessibilityConfig=const AccessibilityConfig(), docsBuilder=defaultDocsBuilder et foldersExpandedByDefault=true.
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/framework/config.dart>
  Q: this.scenarioConfig = const ScenarioConfig(),
         this.accessibilityConfig = const AccessibilityConfig(),
         this.docsBuilder = defaultDocsBuilder,
         this.foldersExpandedByDefault = true,
  ~ Vérifié sur HEAD de la branche v4. Le CHANGELOG n'indique que des correctifs depuis la beta.14, donc la signature est équivalente.
- Les composants se déclarent dans des fichiers `*.stories.dart` qui contiennent `part '<nom>.stories.g.dart';` et un `const meta = Meta(MonWidget.new);`. Ce `Meta` prend en argument positionnel un tear-off de constructeur et doit être `const`. Le générateur produit `_Args`, `_Story`, `_Scenario`, `_Defaults` et `_Component`, plus un registre global `components.g.dart` à la racine de lib.
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/stories/code-generation.mdx>
- Chaque story est une variable top-level préfixée par `$` (ex. `final $Default = _Story(...)`). Le nom de la variable sans le `$` devient le nom affiché, sauf si `name:` est fourni. Le nom 'Docs' est interdit (assert).
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/stories/code-generation.mdx>
  Q: Each story variable must start with `$`.
     The variable name (without the `$`) becomes the story's display name in the Widgetbook UI
- Changement cassant de la beta.7 : l'ancienne syntaxe `const meta = Meta<MyWidget>();` / `MetaWithArgs<MyWidget, MyArgs>()` est remplacée par `const meta = Meta(MyWidget.new)` / `Meta(MyWidget.new, argsType: MyArgs.new)`. `name`, `path` et `docsBuilder` passent dans un `ComponentMeta` optionnel (un au plus par fichier). Les exemples v4 antérieurs à la beta.7 ne compilent donc plus.
  <https://github.com/widgetbook/widgetbook/pull/1931>
- Plusieurs constructeurs par composant : on déclare un `Meta` par constructeur (ex. `const iconMeta = Meta(MyButton.icon);`). Les types générés sont alors préfixés en PascalCase (`_IconStory`, `_IconArgs`, `_IconDefaults`, `_IconScenario`).
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/stories/code-generation.mdx>
  Q: const iconMeta = Meta(MyButton.icon); // [!code highlight]
- Signature de `Story` en beta.14 : `Story({String? name, designLink, setup = defaultSetup, modes, required args, required builder, scenarios = const [], excludeFromTests = false})`. Le `_Story` généré fournit un builder par défaut quand `Meta` cible le widget, sans `argsType`.
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/framework/story.dart>
  Q: Story({
         String? name,
         this.designLink,
         this.setup = defaultSetup,
         this.modes,
         required this.args,
         required this.builder,
         this.scenarios = const [],
         this.excludeFromTests = false,
       })
- Signature de `Scenario` en beta.14 : `Scenario({type = ScenarioType.local, required name, List<Mode>? modes, TArgs? args, run, excludeFromTests = false, mergeModes})`. Le callback `run` a le type `Future<void> Function(WidgetTester tester, TArgs args)`. Les modes du scénario l'emportent sur les modes de la story de même type.
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/framework/scenario.dart>
  ~ Nuance : le docstring de ScenarioDefinition.mergeModes dit l'inverse (story d'abord), mais le code de defaultMergeModes fait gagner les modes du scénario.
  ~ Nuance : `name` est `required super.name` et `mergeModes` est `super.mergeModes`.
- Les Args sont générés à partir des paramètres du constructeur et passés via `_Args(...)`. `Arg.fixed(valeur)` fige une valeur sans contrôle dans l'UI (utile pour les callbacks). `_Args.fixed(...)` prend directement les valeurs brutes (usage typique : les scénarios). Un paramètre requis non primitif et sans défaut devient `required Arg<Type>` : un `_Story()` sans args ne compile pas dans ce cas.
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/args/overview.mdx>
  ~ Nuance : la doc montre aussi _Args.fixed utilisé directement dans une _Story, pas seulement dans les scénarios. Le fait qu'un _Story() sans args ne compile pas est une inférence, cohérente avec le TODO du template de la CLI.
- Constructeurs des Args en beta.14 : `BoolArg(bool value, {String? name})`, `StringArg(String value, {String? name})`, `IntArg(int value, {String? name, style = const InputIntArgStyle()})` (avec aussi `SliderIntArgStyle(min:, max:, divisions:)`), et `EnumArg<T extends Enum>(T value, {name, required values, labelBuilder = enumLabelBuilder, style = const DropdownSingleArgStyle()})`. Chaque type a une variante Nullable* (NullableBoolArg, NullableStringArg, NullableEnumArg…).
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/args/enum_arg.dart>
  Q: EnumArg(
         super.value, {
         super.name,
         required super.values,
         super.labelBuilder = enumLabelBuilder,
         super.style = const DropdownSingleArgStyle(),
       });
- Pour qu'un EnumArg s'affiche en contrôle segmenté plutôt qu'en liste déroulante, on passe `style: const SegmentedSingleArgStyle()`.
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/args/enum.mdx>
  Q: status: EnumArg<OnlineStatusType>( // [!code highlight]
           OnlineStatusType.online, // [!code highlight]
           values: OnlineStatusType.values, // [!code highlight]
           style: const SegmentedSingleArgStyle(), // [!code highlight]
- Valeurs par défaut partagées : une variable de type `_Defaults(setup: (context, child, args) => ..., builder: (context, args) => ...)`, au plus une par variante, est reconnue par son type et non par son nom. Avec `Meta(W.new, argsType: X.new)`, un `builder` est obligatoire, soit par story, soit via `_Defaults`.
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/stories/code-generation.mdx>
- Ordre des addons : le premier de la liste est le widget le plus externe. `ViewportAddon` doit venir avant tous les autres addons et `SemanticsAddon` après tous les autres. `SemanticsAddon` est marqué expérimental.
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/addons/overview.mdx>
  ~ Nuance : la page overview citée ne traite que l'ordre Viewport/Alignment. Les règles 'ViewportAddon avant tous les autres', 'SemanticsAddon après tous les autres' et 'expérimental' viennent de viewport-addon.mdx et semantics-addon.mdx.
- Constructeurs des addons en beta.14 : `MaterialThemeAddon(Map<String, ThemeData> themes)`, `ThemeAddon<T>(Map<String,T> themes, ThemeBuilder<T> builder)`, `LocaleAddon(List<Locale> locales, [List<LocalizationsDelegate> delegates = const []])`, `TextScaleAddon([double scale = 1])`, `GridAddon([int dimension = 50])`, `SemanticsAddon()`, `AlignmentAddon()` et `ZoomAddon()`. À chacun correspond un Mode (MaterialThemeMode(name, theme), LocaleMode, TextScaleMode(double), SemanticsMode(bool), ViewportMode(ViewportData)…).
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/addons/locale_addon.dart>
  Q: LocaleAddon(
         this.locales, [
         this.delegates = const [],
       ]) : assert(locales.isNotEmpty, 'locales cannot be empty'),
  ~ Nuance : SemanticsAddon([bool enabled = false]), AlignmentAddon([Alignment alignment = Alignment.center]) et ZoomAddon([double ratio = 1]) ont un paramètre positionnel optionnel. Ils restent appelables sans argument.
  ~ Nuance : SemanticsAddon([bool enabled = false]), AlignmentAddon([Alignment alignment = Alignment.center]) et ZoomAddon([double ratio = 1]) prennent un paramètre positionnel optionnel. Ils restent appelables sans argument.
- Viewports desktop prédéfinis : `MacosViewports.desktop` ('macOS Desktop', 1920x1080, pixelRatio 2), `MacosViewports.macbookPro` ('MacBook Pro', 1770x970, pixelRatio 2), `WindowsViewports.desktop` ('Windows Desktop', 1920x1080, pixelRatio 2) et `LinuxViewports.desktop` ('Linux Desktop', 1920x1080, pixelRatio 2). S'y ajoutent `Viewports.none` et les listes `.all` (`Viewports.all` couvre iOS, Android, macOS, Windows et Linux).
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/addons/viewport_addon/viewports/macos_viewports.dart>
  Q: static const macbookPro = ViewportData(
         name: 'MacBook Pro',
         width: 1800 - 30,
         height: 1000 - 30,
         pixelRatio: 2,
         platform: TargetPlatform.macOS,
  ~ Nuance : Viewports.all contient aussi Viewports.none en plus des listes iOS, Android, macOS, Windows et Linux.
- Piège de nommage : `package:widgetbook/widgetbook.dart` exporte une classe `ThemeMode<T>` (le Mode de ThemeAddon), homonyme de l'enum `ThemeMode` de `package:flutter/material.dart`. Un fichier qui importe les deux et écrit `ThemeMode` sans préfixe ni `hide` produit une ambiguïté (inférence à partir de l'export, non testée par compilation).
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/lib/src/core/addons/theme_addon/theme_addon.dart>
- DocBlocks : par défaut, `defaultDocsBuilder()` renvoie `[ComponentNameDocBlock(), DartCommentDocBlock(), StoriesDocBlock()]`. Autres blocs disponibles : StoryDocBlock, PrimaryStoryDocBlock, TitleDocBlock(title:), SubtitleDocBlock(title:), TextDocBlock(String), ComposerDocBlock(children:) et WidgetDocBlock(widget). `StoriesDocBlock` a une hauteur fixe de 500 px par défaut, réglable avec `height:` ou supprimée avec `.unconstrained()`. La personnalisation par composant passe par `ComponentMeta(docsBuilder: (blocks) => blocks.replaceFirst<DartCommentDocBlock>(...))`.
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/documentation/doc-blocks.mdx>
- Les scénarios globaux se déclarent dans `Config(scenarioConfig: ScenarioConfig(definitions: [ScenarioDefinition(name:, modes:)], setUp:, tearDown:, wrapper:))`. Depuis la beta.4, `ScenarioConfig` remplace `Config.scenarios`, et une ScenarioDefinition se croise par défaut avec chaque scénario local (`ScenarioStrategy.perScenario`). Lancer `flutter test` écrit les snapshots dans `build/.widgetbook`.
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/testing/run-scenarios.mdx>
- Changements entre beta.9 et beta.14 : beta.10 ajoute `excludeFromTests` à Story et Scenario et réinitialise le cache d'images entre scénarios ; beta.11 reconstruit la preview au changement de story dans un même composant ; beta.12 charge les images avant le snapshot dans testWidgetbook et conserve l'état de la preview entre rebuilds ; beta.13 autorise analyzer 13.x/14.x ; beta.14 ajoute `Config.foldersExpandedByDefault`. Aucun changement cassant n'apparaît après la beta.9 (qui avait ajouté `designLink` et `Config.accessibilityConfig`).
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/CHANGELOG.md>
  Q: ## 4.0.0-beta.14
     
     - **FEAT**: Add `foldersExpandedByDefault` to `Config` to start the navigation tree collapsed
- La branche v4 contient déjà un correctif non publié (section 'Unreleased' du CHANGELOG, PR #2042) : défilement automatique de l'arbre de navigation vers le nœud sélectionné. Une beta.15 est donc probable, mais elle n'est pas publiée au 2026-10-28.
  <https://github.com/widgetbook/widgetbook/blob/v4/packages/widgetbook/CHANGELOG.md>
  Q: ## Unreleased
     
     - **FIX**: Scroll the navigation tree to the selected node and expand its ancestors when the path changes, including on deep links. ([#2042]
- Exemple complet officiel (copie fidèle de examples/full_example, branche v4) : point d'entrée et story.

lib/widgetbook.dart :

void main() { runWidgetbook(Config(components: components, addons: [ViewportAddon(Viewports.all), GridAddon(100), AlignAddon(), ZoomAddon(), ThemeAddon<AppThemeData>({...}, (context, theme, child) { return AppTheme(data: theme, child: child); })])); }

Story (custom_card.stories.dart) :

part 'custom_card.stories.g.dart'; const meta = Meta(CustomCard.new); final $Default = _Story(name: 'Default', args: _Args(child: Arg.fixed(const Text('This is a custom card'))));

Attention : `AlignAddon` est un addon personnalisé défini dans l'exemple ; l'addon fourni par le package s'appelle `AlignmentAddon`.
  <https://github.com/widgetbook/widgetbook/blob/v4/examples/full_example/lib/components/custom_card.stories.dart>
  Q: part 'custom_card.stories.g.dart';
     
     const meta = Meta(CustomCard.new);
     
     final $Default = _Story(
       name: 'Default',
       args: _Args(
         child: Arg.fixed(
           const Text('This is a custom card'),
         ),
       ),
     );
- La doc v4 a une section GenUI (ajoutée le 2026-08-08, PR #2006) qui fait correspondre `CatalogItem.name`, `dataSchema` et `widgetBuilder` du SDK Flutter GenUI à Component, Args et widget de la story. Elle recommande de séparer le widget présentationnel du binding `CatalogItem`, d'utiliser un widget hôte stateful à la place du `DataModel`, et de rejouer des payloads A2UI en cache avec un `_Scenario` par payload. Elle précise que Widgetbook n'a aucune API spécifique à GenUI.
  <https://github.com/widgetbook/widgetbook/blob/v4/docs/genui/overview.mdx>
  Q: Widgetbook has no GenUI-specific API.
       This section uses the same stories, args, scenarios, and modes as the rest of the docs.
  ~ Nuance : overview.mdx ne contient que la table de correspondance et la mention 'no GenUI-specific API'. Les recommandations sur le widget présentationnel, l'hôte stateful et le scénario par payload sont dans genui/catalog.mdx et genui/testing.mdx.
## CONTESTED (0)
## KILLED (0)
## GAPS
- La doc v4 en ligne est servie sous https://docs.widgetbook.io/~v4/... (HTTP 200 vérifié pour /~v4/quick-start, dont le contenu correspond) ; /v4/ renvoie 404. J'ai lu le contenu à partir des sources MDX de la branche v4 du dépôt GitHub (docs/), qui alimentent docs.page. Les URLs citées pointent donc vers GitHub plutôt que vers chaque page ~v4.
- llms.txt (docs.widgetbook.io/llms.txt) répond en 200 mais n'a pas été lu, et je n'ai pas vérifié s'il couvre la v4.
- Le rendu de pub.dev/documentation/widgetbook/4.0.0-beta.14 n'a pas été consulté : les signatures viennent directement de l'archive pub.dev widgetbook-4.0.0-beta.14.tar.gz.
- Aucun code n'a été compilé ni exécuté avec Flutter 3.47 / Dart 3.13. La compatibilité repose sur les contraintes du pubspec et sur l'exemple officiel, qui déclare flutter ^3.47.0.
- La version minimale de build_runner n'est pas imposée par widgetbook (qui dépend de build ^4.0.0 et source_gen ^4.0.0) : ^2.10.1 vient seulement de l'exemple.
- Non couverts en détail : TextScaleAddon, qui ne prend qu'une valeur initiale (le contrôle UI exact n'a pas été vérifié), CupertinoThemeAddon, TimeDilationAddon, la création d'addons et d'args personnalisés, les Integrations, ainsi que les issues GitHub ouvertes spécifiques à la v4.
- L'ambiguïté du nom ThemeMode entre widgetbook et material est déduite des exports, sans test de compilation.

## wb4-migration

## KEPT (26)
- Le dernier widgetbook stable sur pub.dev est 3.25.0, publié le 2026-06-25 et exigeant flutter >=3.44.0. La dernière préversion v4 est 4.0.0-beta.14, publiée le 2026-09-11 et exigeant sdk >=3.10.0 et flutter >=3.38.0. Elle est donc compatible en contrainte avec Flutter 3.47.
  <https://pub.dev/api/packages/widgetbook>
- Cadence des bêtas v4 d'après pub.dev : beta.1 le 2026-02-25, beta.2 le 2026-03-06, beta.3 le 2026-03-31, beta.4 le 2026-06-13, beta.6 à beta.8 entre le 22 et le 25 juin 2026, beta.9 le 2026-07-02, beta.10 le 2026-07-08, beta.11 le 2026-08-01, beta.12 le 2026-08-25, beta.13 le 2026-08-28 et beta.14 le 2026-09-11. Aucune bêta n'est sortie depuis le 11 septembre, soit environ 7 semaines au 2026-10-28. Les alphas remontent à 4.0.0-alpha.1 (2023-12-23).
  <https://pub.dev/api/packages/widgetbook>
- La version 4.0.0-beta.5 n'existe pas sur pub.dev. Elle a été sautée volontairement pour aligner les numéros de version de widgetbook et de widgetbook_cli, qui publie lui aussi des 4.0.0-beta.x jusqu'à beta.14.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz>
- La doc officielle v4 existe sous le préfixe https://docs.widgetbook.io/~v4. Elle a son propre llms.txt (https://docs.widgetbook.io/~v4/llms.txt) et chaque page est disponible en markdown via le suffixe .md. Les chemins /v4 et /next renvoient 404.
  <https://docs.widgetbook.io/~v4/llms.txt>
- La doc v4 affiche un avertissement de bêta : l'API peut casser dans des versions mineures. Il faut donc épingler une version exacte (par exemple widgetbook: 4.0.0-beta.14) plutôt qu'une contrainte en ^.
  <https://docs.widgetbook.io/~v4/whats-new-in-v4>
  ~ Pinning an exact version is the author's inference from the warning. The docs do not recommend it.
  ~ La doc avertit seulement que la version est instable et que l'API peut casser dans des versions mineures. Épingler une version exacte est une recommandation interne qui en découle, pas une consigne de la doc.
- Le guide de migration officiel (page « v4 Migration Guide ») recommande une migration assistée par agent IA. Il fournit un prompt (docs/assets/guides/v4-migration/prompt.md, branche v4) à compléter avec 3 à 5 stories écrites à la main. Sans IA, la voie manuelle passe par la commande `widgetbook init`.
  <https://docs.widgetbook.io/~v4/v4-migration>
- Correspondances officielles v3 → v4 : un use-case `@UseCase` devient une story (`_Story`), un knob `context.knobs` devient un arg typé (`_Args`, `StringArg`, `BoolArg`…), et la configuration à base d'annotations et de fonctions est remplacée par des déclarations générées (`Meta`, `_Story`, `_Args`, `_Scenario`).
  <https://docs.widgetbook.io/~v4/whats-new-in-v4>
- Dépendances en v4 : il faut retirer widgetbook_annotation et widgetbook_generator du pubspec. Depuis 4.0.0-alpha.5, le générateur et widgetbook_test sont fusionnés dans le package widgetbook. widgetbook_generator s'arrête d'ailleurs à 4.0.0-alpha.4 sur pub.dev.
  <https://raw.githubusercontent.com/widgetbook/widgetbook/refs/heads/v4/docs/assets/guides/v4-migration/prompt.md>
- `@App` disparaît en v4. La classe annotée `@App()` qui renvoyait `Widgetbook(directories: directories, …)` à partir de `main.directories.g.dart` est remplacée par une variable `final config = Config(components: components, appBuilder: …, addons: […])` qui importe `components.g.dart`. Le point d'entrée devient `void main() => runWidgetbook(config);`.
  <https://raw.githubusercontent.com/widgetbook/widgetbook/refs/heads/v4/docs/assets/guides/v4-migration/prompt.md>
- Génération en v4 : les stories vont dans des fichiers `*.stories.dart` qui contiennent `part '<nom>.stories.g.dart';` et une variable `const meta = Meta(MonWidget.new);`. On lance ensuite `dart run build_runner build`. Chaque variable de story doit commencer par `$`.
  <https://docs.widgetbook.io/~v4/quick-start>
  Q: part 'custom_button.stories.g.dart'; const meta = Meta(CustomButton.new); ... Run `dart run build_runner build` to generate the boilerplate code. ... A story must start with `$`.
  ~ In the quick start the file lives under widgetbook/lib/.
- Le build.yaml de widgetbook 4.0.0-beta.14 déclare trois builders. `story_builder` transforme les `.stories.dart` en `.stories.g.dart` et ne s'applique par défaut qu'à `lib/**.stories.dart`. `components_builder` produit `components.g.dart`. `telemetry` envoie une télémétrie anonyme et a l'option `debug: false`. Depuis 4.0.0-beta.1, l'extension générée n'est plus `*.book.dart` mais `*.g.dart`.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz>
- Changement cassant en 4.0.0-beta.7 (PR #1931) : `Meta<MyWidget>()` devient `Meta(MyWidget.new)`, qui prend un tear-off de constructeur. `MetaWithArgs<MyWidget, MyArgs>()` devient `Meta(MyWidget.new, argsType: MyArgs.new)`. `name`, `path` et `docsBuilder` passent dans un `ComponentMeta` facultatif, limité à un par fichier. Un constructeur nommé génère des types préfixés (`_IconStory`, `_IconArgs`). Les exemples et billets antérieurs à beta.7 sont donc obsolètes.
  <https://github.com/widgetbook/widgetbook/pull/1931>
- Table officielle knobs → args : `context.knobs.string(...)` devient `StringArg('y')`, `context.knobs.int.slider` devient `IntArg(y, style: SliderIntArgStyle(...))`, `context.knobs.object.dropdown` devient `SingleArg([...])`, `object.segmented` devient `SingleArg([...], style: SegmentedArgStyle())`, et les knobs `orNull` deviennent des args nullables (`NullableStringArg('y')`). Attention : le prompt écrit `BooleanArg`, mais la classe réelle de beta.14 s'appelle `BoolArg` (lib/src/core/args/bool_arg.dart).
  <https://raw.githubusercontent.com/widgetbook/widgetbook/refs/heads/v4/docs/assets/guides/v4-migration/prompt.md>
  ~ The prompt has more errors than BooleanArg. In beta.14 the class is `SegmentedSingleArgStyle`; `SegmentedArgStyle` does not exist. The `SingleArg` constructor is `SingleArg(value, {required values, ...})`, not `SingleArg([...])`.
  ~ En plus de BooleanArg, qui s'appelle en réalité BoolArg : le prompt écrit SegmentedArgStyle(), mais beta.14 n'a pas de classe de ce nom. Les styles réels sont SegmentedSingleArgStyle et DropdownSingleArgStyle, des sous-classes scellées de SingleArgStyle. SliderIntArgStyle et NullableStringArg existent bien.
- Un paramètre de constructeur sans valeur par défaut utilisable (un callback `onPressed` requis, par exemple) doit être fourni dans `args`, typiquement via `Arg.fixed(() {})`. Sans cela, un `_Story()` nu ne compile pas.
  <https://docs.widgetbook.io/~v4/quick-start>
- `DeviceFrameAddon` est supprimé en v4 et remplacé par `ViewportAddon`/`ViewportMode`. `InspectorAddon` et `AccessibilityAddon` sont supprimés eux aussi, dès 4.0.0-alpha.3. Les addons présents dans beta.14 sont : Alignment, Builder, Grid, Locale, TextScale, TimeDilation, Zoom, Semantics, Theme (Material et Cupertino) et Viewport.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz>
- Les addons sont renommés ou changent de signature. `LocalizationAddon(locales:, localizationsDelegates:, initialLocale:)` devient `LocaleAddon(supportedLocales, localizationsDelegates)`. `ThemeAddon(themes: [WidgetbookTheme(...)], themeBuilder: ...)` devient `ThemeAddon<T>({'Light': ..., 'Dark': ...}, (context, theme, child) => ...)`, avec des arguments positionnels. Côté API d'extension, `Addon.buildUseCase` devient `Addon.apply` (alpha.4).
  <https://raw.githubusercontent.com/widgetbook/widgetbook/refs/heads/v4/docs/assets/guides/v4-migration/prompt.md>
  ~ Dans le code de beta.14, la signature est LocaleAddon(locales, [delegates = const []]) : les delegates sont un paramètre positionnel optionnel.
- Le prompt de migration officiel est en partie périmé. Il montre `Config(scenarios: [ScenarioDefinition(...)])`, alors que 4.0.0-beta.4 a remplacé `Config.scenarios` par `Config.scenarioConfig` (type `ScenarioConfig(definitions: [...])`). Le Config de beta.14 n'a bien qu'un paramètre `scenarioConfig`. Il faut donc relire la sortie d'un agent qui suit ce prompt à la lettre.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz>
- Les `cloudKnobsConfigs` et `cloudAddonsConfigs` de v3 deviennent des `scenarios` : `_Scenario(name:, args:, modes:, run: (tester, args) async {...})` au niveau de la story, ou des `ScenarioDefinition` globales. `flutter test`, via `testWidgetbook(config)` importé de `package:widgetbook/test.dart`, écrit les snapshots dans `build/.widgetbook`. Ces scénarios et les tests d'interaction fonctionnent en local, sans Widgetbook Cloud.
  <https://docs.widgetbook.io/~v4/testing/run-scenarios>
  ~ whats-new says 'Widgetbook Cloud supports interaction testing'. Even so, `run` callbacks do execute locally under `flutter test`.
- La doc v4 contient une section GenUI (pages /~v4/genui/overview, /catalog et /testing). Elle fait correspondre `CatalogItem.name` du Flutter GenUI SDK à un composant Widgetbook, `dataSchema` aux args typés et `widgetBuilder` au widget rendu par la story. Elle précise qu'il n'existe aucune API GenUI spécifique.
  <https://docs.widgetbook.io/~v4/genui/overview>
- La page GenUI « Test the Catalog » propose de rejouer des surfaces A2UI mises en cache. Un widget `CachedSurface({required A2uiMessage payload})` est catalogué avec `Meta(CachedSurface.new)` et `Arg.fixed(cachedSurfaces.first)`. Les métadonnées de scénario sont écrites dans `build/.widgetbook/<Component>/<Story>/<Scenario>.json`. Ce schéma colle directement à une démo de talk GenUI.
  <https://docs.widgetbook.io/~v4/genui/testing>
  ~ Per the page, it is accessibility violations that are recorded in that scenario JSON metadata. 'Fits a talk demo' is the author's opinion.
  ~ Dire que ce schéma colle directement à une démo de talk relève de l'appréciation.
- Le développement v4 se fait sur la branche `v4` du dépôt github.com/widgetbook/widgetbook. La branche `main` (branche par défaut) en est encore à widgetbook 3.25.0. Le dernier commit sur `v4` date du 2026-10-12 (#2042, déjà en « Unreleased » dans le CHANGELOG). La PR #2022 du 2026-08-25 a passé les exemples v4 à `flutter: ^3.47.0`.
  <https://github.com/widgetbook/widgetbook/pull/2022>
- Issue ouverte #2044 (2026-10-02) sur material_ui : `MaterialThemeAddon` est encore typé contre `package:flutter/material.dart` et n'accepte pas un `ThemeData` venant de `material_ui`. Le mainteneur recommande d'utiliser entre-temps le `ThemeAddon<T>` générique avec un `themeBuilder` maison. C'est directement bloquant pour le choix « M3 via material_ui » du projet.
  <https://github.com/widgetbook/widgetbook/issues/2044>
  ~ 'Directly blocking' overstates it. The maintainer offers a workaround (the generic ThemeAddon<T>), so it is a constraint, not a blocker.
  ~ « Directement bloquant » est excessif. Le mainteneur indique un contournement viable, ThemeAddon<T> générique avec un themeBuilder maison. MaterialThemeAddon est inutilisable avec material_ui, mais pas Widgetbook. Autre point : l'UI de Widgetbook elle-même ne migrera pas vers material_ui, car l'équipe prévoit son propre design system.
- Issue ouverte #1984 (beta.10 et beta.11) : quand on passe d'une story sœur à une autre, l'aperçu peut garder l'état de la story précédente si `setup` injecte un `BlocProvider`. Les correctifs beta.11 (#1994) et beta.12 (#2012) ne règlent pas ce cas, et la PR #2020 a été fermée. C'est un risque concret pour un projet en flutter_bloc qui fournit ses Blocs via `setup`.
  <https://github.com/widgetbook/widgetbook/issues/1984>
- Autres issues ouvertes qui comptent pour une démo web ou desktop. #1797 : la stratégie d'URL « path » n'est pas supportée et un rechargement ou un lien profond renvoie à l'accueil, sur `flutter run -d chrome` comme sur `flutter build web`. #2043 : `TimeDilationAddon` ralentit aussi les animations de l'interface Widgetbook. #2041 : `NullableDoubleArg` ne borne pas `initialValue` entre min et max. #1747 : `MaterialThemeAddon` casse les styles hover et pressed des widgets qui dépendent d'un ancêtre `Material`.
  <https://github.com/widgetbook/widgetbook/issues/1797>
  ~ #1747 was reported against widgetbook 3.19.0 (v3). Its relevance to v4 is unconfirmed.
- `widgetbook init`, la commande qui amorce un projet v4 en manuel, est marquée expérimentale dans la doc v4. Elle accepte `--package`, `--output` et `--empty`. L'installation passe par `dart pub global activate widgetbook_cli` : le dernier stable est 3.15.0, et la ligne 4.0.0-beta.x suit widgetbook jusqu'à beta.14.
  <https://docs.widgetbook.io/~v4/cli/commands/init>
- Collision de noms : widgetbook 4.0.0-beta.14 exporte une classe générique `ThemeMode<T> extends Mode<T>` (theme_addon.dart), homonyme de l'enum `ThemeMode` de Flutter. Or `Config` utilise lui-même l'enum Flutter (`themeMode = ThemeMode.system`). Un fichier qui importe à la fois material et widgetbook devra masquer l'un des deux (`hide`) ou passer par un préfixe.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz>
## CONTESTED (0)
## KILLED (0)
## GAPS
- Aucune date de sortie de la 4.0 stable n'est annoncée. La page whats-new-in-v4 dit seulement : « We will announce the final pricing plans before general availability. » Aucun milestone GitHub ni aucune issue ne fixe d'échéance.
- Le build web et desktop de la v4 n'a pas été testé avec Flutter 3.47.x. La compatibilité ne repose que sur la contrainte flutter >=3.38.0 et sur la PR #2022 qui passe les exemples à 3.47.
- Les issues ouvertes n'ont pas d'étiquette « v4 ». Le filtrage v3/v4 a donc été fait à la main, d'après le contenu des issues (#1984 cite explicitement beta.10 et beta.11).
- La PR #2020 (remontage du wrapper par chemin) est fermée, sans que j'aie vérifié si elle a été fusionnée ailleurs. Le correctif #2042 du 2026-10-12 n'est pas encore publié.
- Le prompt de migration officiel présente des incohérences avec beta.14 (Config.scenarios, BooleanArg). D'autres écarts ne sont pas exclus, car il n'a pas été relu ligne par ligne.
- Les sujets Claude Design et Anthropic n'étaient pas couverts par cette tâche, centrée sur Widgetbook.

## wb4-testing

## KEPT (25)
- La dernière pré-version de widgetbook est 4.0.0-beta.14, publiée sur pub.dev le 2026-09-11 ; la version stable « latest » reste 3.25.0. widgetbook_cli suit le même numéro (4.0.0-beta.14, même date, stable 3.15.0).
  <https://pub.dev/api/packages/widgetbook>
- widgetbook 4.0.0-beta.14 exige Dart >=3.10.0 <4.0.0 et Flutter >=3.38.0, donc il est compatible avec Flutter 3.47. Le package dépend directement de flutter_test, build, source_gen et analyzer >=8.0.0 <15.0.0.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (pubspec.yaml)>
  Q: sdk: ">=3.10.0 <4.0.0"
       flutter: ">=3.38.0"
  ~ Compatibility with Flutter 3.47 is an inference from the constraint, not a tested fact.
- Le package widgetbook_test est obsolète en v4. Depuis 4.0.0-alpha.5, il est fusionné dans widgetbook avec le générateur. Sur pub.dev, widgetbook_test n'a jamais dépassé 4.0.0-alpha.3 (publiée le 2025-10-10). Il ne faut donc PAS l'ajouter en dépendance avec la beta.14.
  <https://pub.dev/packages/widgetbook/versions/4.0.0-beta.14/changelog>
  ~ Nuance : la version « latest » stable de widgetbook_test sur pub.dev est 3.0.0, publiée le même jour. La plus haute version est bien 4.0.0-alpha.3, du 2025-10-10.
- Dans widgetbook_test 4.0.0-alpha.3, le changelog ne contient qu'une seule entrée : l'ajout de la fonction testWidgetbook. Le package dépendait de widgetbook ^4.0.0-alpha.3.
  <https://pub.dev/api/archives/widgetbook_test-4.0.0-alpha.3.tar.gz (CHANGELOG.md)>
  ~ Nuance : la section 4.0.0-alpha.3 n'a qu'une entrée, mais le fichier CHANGELOG contient aussi une section 0.0.0 « Empty release ».
  ~ Nuance: the CHANGELOG also has a '## 0.0.0 - Empty release.' entry, so the alpha.3 entry is the only substantive one.
- En beta.14, testWidgetbook a la signature `Future<void> testWidgetbook(Config config)`. On l'importe via `package:widgetbook/test.dart`, qui exporte src/test/test.dart en masquant la constante outputDir. La fonction appelle TestWidgetsFlutterBinding.ensureInitialized() puis loadFonts(), et crée un group() par composant, un group() par story et un testWidgets() par scénario.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (lib/src/test/test.dart, lib/test.dart)>
  Q: Future<void> testWidgetbook(Config config) async {
       TestWidgetsFlutterBinding.ensureInitialized();
       await loadFonts();
- La doc v4 indique de créer le point d'entrée test/widgetbook_test.dart, qui appelle `await testWidgetbook(config);` dans main(), puis de lancer `flutter test`. Chaque scénario produit une image PNG et un fichier JSON de métadonnées dans build/.widgetbook.
  <https://docs.widgetbook.io/~v4/testing/run-scenarios>
  ~ Formulation exacte de la doc : « Each scenario writes a PNG snapshot image and a JSON metadata file », par défaut dans build/.widgetbook.
- testWidgetbook n'est PAS un test golden local. Il écrit `build/.widgetbook/<Component>/<Story>/<Scenario>.png` et `.json`, sans appeler matchesGoldenFile ni goldenFileComparator, et ne compare rien à une référence. Le JSON contient un hash sha256 de l'image, sa taille, le pixelRatio, l'arbre de sémantique et les violations. Les « / » du nom de scénario sont remplacés par « _ ».
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (lib/src/test/scenario_metadata.dart, lib/src/test/test.dart)>
- Le diff visuel des snapshots est fait par Widgetbook Cloud, pas par la bibliothèque. Sans Cloud, il n'existe aucun diff fourni : la régression visuelle doit passer par des goldens Flutter classiques (ou alchemist) écrits à part. L'issue #678 « Golden Testing with Widgetbook » est toujours ouverte, et l'équipe y renvoie vers le Cloud.
  <https://github.com/widgetbook/widgetbook/issues/678>
  ~ Nuance: in #678 the maintainer (June 2024) also said golden support would come to the OSS package with v4. As of beta.14 that has not happened: there is still no comparison.
- La page v4 GenUI/testing réserve le diff des snapshots et des régressions d'accessibilité à la publication sur Widgetbook Cloud, en comparant à la branche de base.
  <https://docs.widgetbook.io/~v4/genui/testing>
- Les violations d'accessibilité ne font jamais échouer flutter test. Elles sont seulement écrites dans le JSON du scénario. Pour un gate CI sans Cloud, il faut lire build/.widgetbook/**/*.json (clé "violations") avec un script, ou faire des expect explicites dans run.
  <https://docs.widgetbook.io/~v4/genui/testing>
  ~ Faire des expect dans run est une déduction, pas une recommandation de la doc.
- Config possède un paramètre `accessibilityConfig`, dont la valeur par défaut est `const AccessibilityConfig()`. AccessibilityConfig n'a qu'un champ, `final List<WidgetbookGuideline> guidelines`, qui vaut par défaut `WidgetbookGuidelines.recommended`. La fonctionnalité date de 4.0.0-beta.9 (PR #1954).
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (lib/src/core/accessibility/accessibility_config.dart, lib/src/core/framework/config.dart)>
  Q: const AccessibilityConfig({
         this.guidelines = WidgetbookGuidelines.recommended,
       });
- Tous les noms demandés existent toujours dans beta.14 et sont exportés par package:widgetbook/widgetbook.dart via src/core/accessibility/accessibility.dart : WidgetbookGuideline (abstraite, `String get id` et `Future<List<GuidelineViolation>> evaluate(WidgetTester tester)`), FlutterGuideline, MinTapTargetGuideline, LabeledTappableGuideline, WidgetbookGuidelines, evaluateGuidelines, GuidelineViolation et ViolationNode.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (lib/src/core/accessibility/guideline.dart, guidelines.dart)>
  Q: abstract class WidgetbookGuideline {
     const WidgetbookGuideline();
     
     String get id;
     
     Future<List<GuidelineViolation>> evaluate(WidgetTester tester);
  ~ Précision : les noms sont réexportés via accessibility.dart puis guidelines.dart, qui réexporte flutter_guideline, guideline, guideline_violation, native et violation_node.
- WidgetbookGuidelines.recommended contient quatre règles : MinTapTargetGuideline(id: 'tap-target-android', size: Size(48, 48)), MinTapTargetGuideline(id: 'tap-target-ios', size: Size(44, 44)), LabeledTappableGuideline() (id par défaut 'labeled-tappable') et FlutterGuideline(textContrastGuideline, id: 'text-contrast').
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (lib/src/core/accessibility/guidelines.dart)>
  Q: LabeledTappableGuideline(),
         FlutterGuideline(textContrastGuideline, id: 'text-contrast'),
- La règle de contraste (text-contrast) est adaptée de la règle Flutter. Elle ne porte que sur le texte, reste approximative et doit être prise comme indicative. C'est important pour valider les tokens M3 : il ne faut pas s'en servir comme preuve de conformité WCAG.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (lib/src/core/accessibility/guidelines.dart)>
  Q: contrast is adapted from Flutter's built-in guideline and is text-only and
     /// approximate — treat it as advisory.
  ~ La mise en garde sur la conformité WCAG des tokens M3 est une conclusion de l'auteur, pas un énoncé du package.
  ~ The advice not to treat it as proof of WCAG compliance is an interpretation, though a reasonable one.
- FlutterGuideline a pour constructeur `const FlutterGuideline(AccessibilityGuideline guideline, {required String id, String? helpUrl})`. Il enveloppe une AccessibilityGuideline de flutter_test (par exemple androidTapTargetGuideline). Ses violations portent un `reason` et non des nœuds par élément.
  <https://docs.widgetbook.io/~v4/testing/accessibility>
- LabeledImageGuideline (id 'labeled-image') n'existe pas dans le package beta.14. C'est un exemple de règle personnalisée donné dans la doc, à coder soi-même en implémentant WidgetbookGuideline. La doc demande de garder un `id` stable, car les violations sont suivies par id.
  <https://docs.widgetbook.io/~v4/testing/accessibility>
- Pour désactiver l'évaluation, on passe `AccessibilityConfig(guidelines: const [])`. L'arbre de sémantique reste capturé dans le JSON. Si une règle lève une exception, evaluateGuidelines l'enregistre comme GuidelineViolation et le snapshot n'est pas bloqué.
  <https://docs.widgetbook.io/~v4/testing/accessibility>
- GuidelineViolation a pour constructeur `const GuidelineViolation({required String guidelineId, required String title, String? helpUrl, List<ViolationNode> nodes = const [], String? reason})`. Sa méthode toJson() sérialise les clés 'id', 'title', 'helpUrl', 'nodes' et 'reason'.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (lib/src/core/accessibility/guideline_violation.dart)>
  Q: required this.guidelineId,
         required this.title,
         this.helpUrl,
         this.nodes = const [],
         this.reason,
  ~ Nuance : toJson sérialise toujours 'id' et 'title'. Les clés 'helpUrl', 'nodes' et 'reason' ne sont présentes que si elles sont non nulles ou non vides.
  ~ Nuance: helpUrl, nodes and reason are serialized only when set or non-empty.
- Config.scenarioConfig (type ScenarioConfig) remplace Config.scenarios depuis beta.4. Ses paramètres sont definitions, nameBuilder, setUp, tearDown (ScenarioCallback = `Future<void> Function(WidgetTester, Scenario)`) et wrapper (ScenarioWrapper, ajouté en beta.6, utile pour package:clock). La stratégie par défaut d'une ScenarioDefinition est ScenarioStrategy.perScenario.
  <https://pub.dev/packages/widgetbook/versions/4.0.0-beta.14/changelog>
- Scenario a un callback `run` de type `Future<void> Function(WidgetTester tester, TArgs args)?`, exécuté avant la capture. On peut y écrire des tap/pump/expect, y compris un `expectLater(..., matchesGoldenFile(...))` Flutter classique pour un golden local versionné. Cette dernière possibilité est une déduction tirée de la signature, pas une API documentée.
  <https://pub.dev/api/archives/widgetbook-4.0.0-beta.14.tar.gz (lib/src/core/framework/scenario.dart)>
- `excludeFromTests` sur Story et sur Scenario (depuis beta.10) exclut un élément de la génération de snapshots par testWidgetbook, mais il reste visible dans l'app. flutter test le signale comme « skipped ».
  <https://pub.dev/packages/widgetbook/versions/4.0.0-beta.14/changelog>
- Le rendu est fait par le moteur flutter_test : le viewport du scénario fixe physicalConstraints et devicePixelRatio, ou Viewports.none si aucun n'est défini. loadFonts() charge les polices du FontManifest et widgetbook fournit Roboto. Il faut déclarer les polices custom avec `package:` : sinon le texte apparaît en rectangles noirs (issue #1991). Les pixels varient donc selon l'OS hôte : il faut un runner CI fixe, comme pour tout golden Flutter.
  <https://github.com/widgetbook/widgetbook/issues/1991>
  ~ Nuance : l'issue #1991, close le 2026-07-30, concerne les polices déclarées dans un package de dépendance local, qui doivent être référencées avec `package:`. Elle ne parle pas de toute police custom. La variabilité des pixels selon l'OS est une déduction générale, absente de la source.
  ~ Nuance: the `package:` requirement applies to fonts declared in a dependency package (issue #1991: a separate assets package). A font declared in the app's own pubspec works with its plain family name.
- La commande `widgetbook coverage` existe toujours dans widgetbook_cli 4.0.0-beta.14 et reste marquée expérimentale. Options : --package (défaut ./), --widgetbook (défaut ./widgetbook) et --min-coverage (défaut 100, entre 0 et 100). Elle renvoie ExitCode.success si le seuil est atteint, et -8 sinon, ce qui permet de l'utiliser comme gate CI. L'annotation `// widgetbook: ignore` exclut un widget du calcul.
  <https://pub.dev/api/archives/widgetbook_cli-4.0.0-beta.14.tar.gz (lib/src/commands/coverage.dart)>
  Q: return isSatisfied ? ExitCode.success.code : -8;
- Dans la CLI v4, la seule commande qui consomme build/.widgetbook est `widgetbook cloud build push`, qui demande d'avoir lancé `flutter test` au préalable. Sans Cloud, il n'y a pas de commande CLI pour exploiter les snapshots localement.
  <https://pub.dev/api/archives/widgetbook_cli-4.0.0-beta.14.tar.gz (lib/src/commands/build_push.dart)>
- Depuis 4.0.0-beta.12, testWidgetbook attend le chargement des images avant la capture (PR #2019). Depuis beta.10, il vide l'image cache entre deux scénarios.
  <https://pub.dev/packages/widgetbook/versions/4.0.0-beta.14/changelog>
## CONTESTED (0)
## KILLED (0)
## GAPS
- Compatibilité avec alchemist : aucune doc, issue ou exemple officiel Widgetbook ne la mentionne (recherche GitHub 'alchemist' sans résultat). testWidgetbook crée lui-même ses testWidgets, et goldenTest d'alchemist ne peut pas s'appeler depuis un Scenario.run. La coexistence passe donc par des fichiers de test séparés (déduction, non vérifiée).
- Aucun comparateur golden local fourni par Widgetbook v4 : la combinaison matchesGoldenFile dans Scenario.run n'a pas été testée en pratique.
- Le JSON de build/.widgetbook n'a pas de schéma publié ni stable (clés lues dans le source de ScenarioMetadata.toJson) : un gate CI maison reste fragile entre deux bêtas.
- Doc v4 GitHub Actions / CI hors Cloud : pas de page trouvée, les guides CI ne couvrent que l'upload vers le Cloud.
- Section Fonts de la doc v4 non lue en détail.
- Comportement de testWidgetbook sur une cible web (flutter test --platform chrome) : non documenté, et dart:io est utilisé pour écrire les fichiers (probablement incompatible).
