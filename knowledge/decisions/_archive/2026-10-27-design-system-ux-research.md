# Archive brute — recherche design system Flutter, Widgetbook et UX (2026-10-27)

Sorties brutes de deux passes de recherche (workflows deep-research wf_a1123099-170 et ds-research-pass2 wf_31499446-13d). Passe 1 : 126 affirmations extraites, 25 vérifiées (vote 3 vérificateurs). Passe 2 : 11 sujets, 2 vérificateurs adverses (exactitude, actualité) par sujet ; KEPT = 0 réfutation, CONTESTED = 1 sur 2.

## Passe 1 — synthèse vérifiée

- [high, 3-0] Versions de Widgetbook au 2026-10-27 : la stable est 3.25.0 (environ 4 mois), la préversion est 4.0.0-beta.14 (environ 46 jours). La 4.0 est une bêta dont l'API peut encore changer, donc un design system de production doit cibler la 3.x. — https://pub.dev/packages/widgetbook/versions, https://pub-web-s1.flutter-io.cn/packages/widgetbook/versions/3.14.2/changelog
- [high, 3-0] En 3.x, les addons enveloppent tous les use cases dans des widgets configurables depuis l'interface Widgetbook. Ils se déclarent une fois à la racine et leur ordre compte : le premier est le wrapper le plus externe, le dernier le plus interne. Par exemple, ViewportAddon doit précéder AlignmentAddon, sinon c'est le viewport qui est centré au lieu du use case. — https://docs.widgetbook.io/addons/overview
- [high, 2-1 / 3-0] Addons intégrés en 3.x : Alignment, Builder, Custom, Grid, Inspector, Localization, Text Scale, Theme, Time Dilation, Viewport et Zoom. Semantics est expérimental et peut casser à n'importe quelle version mineure. Accessibility est déprécié depuis 3.8.0 : le remplacer par BuilderAddon combiné au package accessibility_tools. Device Frame est déprécié depuis 3.15.0 au profit de Viewport. — https://docs.widgetbook.io/llms.txt, https://pub.dev/packages/widgetbook/changelog
- [high, 3-0] Historique de l'API à connaître pour éviter le code obsolète : 3.10.0 déprécie le paramètre `scales` de TextScaleAddon. 3.11.0 déprécie WidgetbookCloudIntegration, qu'on peut supprimer sans risque. 3.12.0 ajoute ViewportAddon (expérimental). 3.13.0 ajoute SemanticsAddon (expérimental) et remplace device_frame par device_frame_plus. 3.14.0 supprime ViewportData.id au profit de ViewportData.name et ajoute safeAreas. — https://pub.dev/packages/widgetbook/changelog, https://pub-web-s1.flutter-io.cn/packages/widgetbook/versions/3.14.2/changelog
- [high, 3-0] Knobs en 3.x : on y accède par context.knobs (un getter qui renvoie un builder) pour modifier à chaud les paramètres d'un use case. Chaque knob exige un `label`, unique au sein du use case. `initialValue` et `description` sont optionnels, et `description` sert de documentation dans l'app. Types fournis : boolean, int.input/int.slider, double.input/double.slider, string, duration, dateTime, color, iterable.segmented, object.dropdown/object.segmented, chacun avec sa variante OrNull (booleanOrNull, intOrNull.slider, objectOrNull.dropdown…). — https://docs.widgetbook.io/knobs/overview
- [high, 3-0] La 4.0 bêta remplace UseCase/knobs par Story/Scenario/Component et des Args typés : BoolArg, IntArg, DoubleArg, StringArg, ColorArg, DateTimeArg, DurationArg, EnumArg et IterableArg, leurs variantes Nullable*, plus SingleArg, StyledArg, ConstArg et BuilderArg. Ces Args s'appuient sur des classes Field. Les addons y deviennent des args globaux : ThemeAddon, MaterialThemeAddon, CupertinoThemeAddon, ViewportAddon, TextScaleAddon, LocaleAddon, GridAddon, SemanticsAddon, ZoomAddon, AlignmentAddon, BuilderAddon et TimeDilationAddon. DeviceFrameAddon et InspectorAddon n'y figurent pas. — https://pub.dev/documentation/widgetbook/4.0.0-beta.9/widgetbook
- [medium, 3-0] La 4.0 bêta apporte de l'outillage d'accessibilité côté test. AccessibilityConfig, via Config.accessibilityConfig, s'applique à chaque scénario capturé par testWidgetbook. Les WidgetbookGuideline (FlutterGuideline, LabeledTappableGuideline, MinTapTargetGuideline, ensemble par défaut WidgetbookGuidelines, fonction evaluateGuidelines) évaluent l'arbre de widgets et renvoient des GuidelineViolation structurées. — https://pub.dev/documentation/widgetbook/4.0.0-beta.9/widgetbook
- [high, 3-0] Widgetbook Cloud fonctionne ainsi. La CLI pousse les builds (`widgetbook cloud build push`). Les Turbo Builds réutilisent le build précédent quand son hash est inchangé ; on les désactive avec `--no-turbo`, et ils sont peu fiables si des URL externes ou des requêtes réseau modifient le rendu. La facturation se fait au snapshot, par mois. Les revues Figma comparent les widgets aux maquettes. Une visual pull request est créée automatiquement pour chaque PR de code d'un dépôt connecté : GitHub, GitLab, Azure ou Bitbucket. Codemagic n'est qu'une intégration CI, à associer à un VCS. — https://docs.widgetbook.io/llms.txt, https://docs.widgetbook.io/cloud/builds/turbo
- [high, 3-0] Les revues multi-snapshots produisent plusieurs snapshots par use case, un par configuration (thème, locale, appareil). La matrice se déclare sous forme de map nommée dans `@App(cloudAddonsConfigs: {...})`, par exemple 'German Dark' = viewport iPhone 12 + locale allemande + thème sombre. Les variantes de knobs passent par `cloudKnobsConfigs` sur `@UseCase`. Le coût suit le nombre de configurations de knobs multiplié par le nombre de configurations d'addons. — https://docs.widgetbook.io/cloud/snapshots/multi-snapshot
- [high, 3-0] Le format DTCG (Design Tokens Format Module) 2025.10 est la première version stable, publiée le 2025-10-28 comme Final Community Group Report. Ce n'est ni un standard W3C ni un texte sur la voie de standardisation. Fichiers JSON : extensions recommandées `.tokens` et `.tokens.json`, type média `application/design-tokens+json`, `application/json` également accepté. — https://www.w3.org/community/reports/design-tokens/CG-FINAL-format-20251028/, https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/
- [high, 3-0] Règles normatives du DTCG. Un objet n'est un token que s'il a une propriété `$value`, la seule obligatoire. `$type` est optionnel et s'hérite du groupe parent le plus proche. Les outils NE DOIVENT PAS deviner le type d'après la valeur, et un token sans type déterminable est invalide. Le format définit 7 types simples (color, dimension, fontFamily, fontWeight, duration, cubicBezier, number) et 6 types composites (strokeStyle, border, transition, shadow, gradient, typography). — https://www.w3.org/community/reports/design-tokens/CG-FINAL-format-20251028/
- [high, 3-0] Le DTCG 2025.10 gère thèmes et marques : modes clair/sombre, variantes d'accessibilité, marques, avec alias, héritage et références. Le thématisage ne vit pas dans le fichier Format mais dans le module Resolver séparé (sets, modifiers avec contexts, resolutionOrder où la dernière valeur l'emporte, $ref). L'absence de duplication n'est que partielle, et les marques n'ont pas d'exemple travaillé. — https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/, https://www.designtokens.org/tr/2025.10/
- [high, 3-0] Chaîne tokens → Flutter. Un même fichier DTCG peut générer du code pour plusieurs plateformes, dont Flutter, mais ce sont les outils qui génèrent (Style Dictionary, Terrazzo, dtcg_theme), pas la spec. La cible côté Flutter est ThemeExtension, l'interface officielle pour ajouter des propriétés à ThemeData. On l'enregistre via ThemeData(extensions: [...]), on la lit via Theme.of(context).extension<T>(), et elle impose copyWith et lerp, ce qui rend les changements de thème animables. — https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/, https://api.flutter.dev/flutter/material/ThemeExtension-class.html
- [medium, 3-0] dtcg_theme 0.7.1 (environ septembre 2026, éditeur vérifié bomsamdi.com) génère des ThemeExtension typées à partir de fichiers DTCG, avec une constante par mode (AppTokens.light/dark, ou `defaults` sans modes). Son README admet que ses dialectes d'import Figma Variables et Tokens Studio n'ont pas été vérifiés sur de vrais exports : une chaîne Figma → Dart qui repose dessus reste non éprouvée. — https://pub.dev/packages/dtcg_theme

Caveats :
1. Couverture très inégale : les 25 affirmations retenues ne portent que sur Widgetbook et les design tokens (DTCG, ThemeExtension). Rien de vérifié sur la structure d'un catalogue Widgetbook généré (@UseCase, widgetbook_annotation/widgetbook_generator, pub workspace), sur les goldens tirés des use cases, sur Atomic Design, ColorScheme.fromSeed/HCT/Material Color Utilities, les harmonies de couleurs, OKLCH, WCAG 2.2/APCA, la typographie, la grille 4/8 pt, l'élévation, le motion ou la gouvernance d'un package. Rien non plus sur l'UX desktop (clavier, focus, raccourcis, menus contextuels, densité, Fluent/HIG) ni sur l'UX GenUI/A2UI. Ces volets ne doivent pas entrer dans la base sans une nouvelle passe sourcée.
2. Sensibilité au temps : Widgetbook 4.0 est en bêta (beta.9 documentée, beta.14 publiée) et son API peut changer. Les statuts expérimentaux de Semantics et Viewport en 3.x sont à revérifier.
3. Les sources sont surtout celles de l'éditeur (docs.widgetbook.io) et des miroirs pub.dev (flutter-io.cn), recoupés avec pub.dev. Une URL de doc a déménagé (multi-snapshot).
4. Le DTCG est un rapport de Community Group et non une Recommendation W3C. Le thématisage dépend du module Resolver, inégalement pris en charge par les outils.
5. dtcg_theme est un package jeune, et rien n'atteste que sa chaîne Figma fonctionne réellement.

## Passe 2 — a11y-contrast

## KEPT (23)
- WCAG 2.2 est une Recommandation W3C datée du 12 décembre 2024 (REC-WCAG22-20241212).
  <https://www.w3.org/TR/WCAG22/>
  ~ Nuance : c'est l'édition mise à jour. La première Recommandation WCAG 2.2 date du 5 octobre 2023.
- SC 1.4.3 Contrast (Minimum), niveau AA : le texte et les images de texte doivent avoir un contraste d'au moins 4.5:1, et le texte de grande taille d'au moins 3:1. Le texte d'un composant inactif et les logos ou noms de marque n'ont aucune exigence de contraste.
  <https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html>
  ~ The exception also covers text that is pure decoration, invisible, or part of a picture with significant other visual content.
- Au sens WCAG, le « grand texte » fait au moins 18 pt, ou 14 pt en gras. Avec 1 pt = 1,333 px CSS, cela donne environ 24 px et 18,5 px.
  <https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html>
- Les ratios de contraste WCAG ne s'arrondissent pas : 4.499:1 échoue au seuil 4.5:1 (SC 1.4.3), et 2.999:1 échoue au seuil 3:1 (SC 1.4.11). Les tests du design system doivent comparer la valeur brute.
  <https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html>
  ~ The 2.999:1 example is not on the cited contrast-minimum page. It is on the Understanding 1.4.11 page (non-text-contrast.html): 'e.g. 2.999:1 would not meet the 3:1 threshold'.
  ~ Nuance : l'exemple 4.499:1 vient de la page Understanding 1.4.3. Pour 2.999:1 sous 1.4.11, c'est le même principe de non-arrondi, appliqué par analogie.
- SC 1.4.6 Contrast (Enhanced), niveau AAA : 7:1 pour le texte et 4.5:1 pour le grand texte, avec les mêmes exceptions (texte incident, logos).
  <https://www.w3.org/TR/WCAG22/>
  ~ Nuance : les exceptions « incidental » comprennent aussi le texte des composants inactifs, la décoration pure et le texte invisible.
- SC 1.4.11 Non-text Contrast (AA) : l'information visuelle qui permet d'identifier les composants d'UI et leurs états doit atteindre 3:1 contre les couleurs adjacentes. Les composants inactifs (disabled) sont exemptés. Les parties de graphiques nécessaires à la compréhension sont aussi concernées.
  <https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html>
  ~ Graphical objects have their own exception: a particular presentation that is essential to the information.
- Sous 1.4.11, l'information qui indique un état (sélectionné, focalisé) doit atteindre 3:1. En revanche, un effet de survol (hover) purement supplémentaire n'a pas besoin de 3:1, tant que le composant ne perd pas son propre contraste avec les couleurs adjacentes.
  <https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html>
- SC 1.4.1 Use of Color, niveau A : la couleur ne doit pas être le seul moyen visuel de transmettre une information, d'indiquer une action, de solliciter une réponse ou de distinguer un élément.
  <https://www.w3.org/TR/WCAG22/>
- SC 1.4.4 Resize Text, niveau AA : sauf sous-titres et images de texte, le texte doit pouvoir être agrandi jusqu'à 200 % sans technologie d'assistance, sans perte de contenu ni de fonctionnalité.
  <https://www.w3.org/TR/WCAG22/>
- SC 1.4.12 Text Spacing, niveau AA : rien ne doit être perdu quand l'utilisateur règle la hauteur de ligne à au moins 1,5 fois la taille de police, l'espace après paragraphe à 2 fois, l'interlettrage à 0,12 fois et l'espacement des mots à 0,16 fois.
  <https://www.w3.org/TR/WCAG22/>
  ~ There is an exception for human languages/scripts that do not use one of these text-style properties.
- SC 2.4.7 Focus Visible, niveau AA : toute interface utilisable au clavier doit offrir un mode où l'indicateur de focus clavier est visible.
  <https://www.w3.org/TR/WCAG22/>
- SC 2.4.11 Focus Not Obscured (Minimum), niveau AA : le composant qui reçoit le focus ne doit pas être entièrement masqué par du contenu de l'auteur (en-tête ou pied sticky, dialogue non modal, bannière cookies). Un masquage partiel est admis en AA. SC 2.4.12 (AAA) interdit tout masquage.
  <https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html>
- SC 2.4.13 Focus Appearance est de niveau AAA, pas AA. Une zone de l'indicateur de focus doit être au moins aussi grande qu'un périmètre de 2 px CSS d'épaisseur autour du composant non focalisé. Elle doit aussi présenter un contraste d'au moins 3:1 entre les mêmes pixels à l'état focalisé et à l'état non focalisé.
  <https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html>
  ~ Exceptions exist when the user agent determines the indicator and the author does not modify it.
- SC 2.5.8 Target Size (Minimum), niveau AA : 24 × 24 px CSS minimum pour les cibles de pointeur. Cinq exceptions existent : Spacing (un cercle de 24 px de diamètre centré sur la cible ne touche aucune autre cible), Equivalent, Inline, User Agent Control et Essential.
  <https://www.w3.org/TR/WCAG22/>
  ~ Spacing exception details: the circle is centered on the bounding box of each undersized target. It must not intersect another target or the circle of another undersized target. Essential also includes 'legally required'.
  ~ L'exception Spacing exacte : les cibles de moins de 24×24 sont placées de sorte que des cercles de 24 px de diamètre, centrés sur la boîte englobante de chacune, ne coupent aucune autre cible ni le cercle d'une autre cible trop petite.
- SC 2.5.5 Target Size (Enhanced), niveau AAA : 44 × 44 px CSS minimum. Les exceptions sont Equivalent, Inline, User Agent Control et Essential. La page Understanding 2.5.8 conseille de viser 2.5.5 pour les contrôles importants.
  <https://www.w3.org/TR/WCAG22/>
  ~ The Understanding 2.5.8 page says 'For important links/controls, consider aiming for the stricter 2.5.5', which is a soft suggestion.
- WCAG 3.0 n'est qu'un Working Draft (version du 10 septembre 2026). L'algorithme de contraste y reste indéterminé : l'exigence « Text contrast (minimum) » contient un marqueur « @@[contrast measure to be determined] ». APCA n'est donc pas normatif.
  <https://www.w3.org/TR/wcag-3.0/>
  ~ The exact requirement name is 'Text contrast sufficient (minimum)', not 'Text contrast (minimum)'. Its text: 'The default visual presentation of text meets @@[contrast measure to be determined].'
- Selon la doc de l'auteur d'APCA, ni APCA ni WCAG 3.0 ne sont recommandés officiellement par le W3C. Niveaux Lc « Bronze » : Lc90 préféré pour le corps de texte, Lc75 minimum pour le corps de texte (>18px), Lc60 pour le texte fluide moyen (>24px), Lc45 pour le grand texte (>36px), Lc30 minimum absolu, Lc15 seuil d'invisibilité.
  <https://github.com/Myndex/apca-introduction>
  ~ Lc45 also covers 'subfluent text minimum'. Lc30 is the 'minimum for any sub-fluent or spot text'.
  ~ Nuance : Lc60 vaut aussi pour 16px en gras, et Lc45 pour 24px en gras. Lc75 se lit « au moins 18px/400 ».
- Flutter : MediaQueryData.textScaleFactor est déprécié depuis la v3.12.0-2.0.pre au profit de textScaler (TextScaler), en vue du support de la mise à l'échelle non linéaire. On le lit avec MediaQuery.textScalerOf(context).
  <https://api.flutter.dev/flutter/widgets/MediaQueryData/textScaleFactor.html>
  ~ The textScaleFactor page itself does not mention MediaQuery.textScalerOf; it refers to textScaleFactorOf. textScalerOf exists separately (api.flutter.dev MediaQuery/textScalerOf) and falls back to TextScaler.noScaling.
  ~ Nuance de formulation : la doc dit « deprecated after v3.12.0-2.0.pre ». L'API est toujours présente, signalée comme à retirer dans une future version.
- Flutter : MediaQueryData.highContrast correspond à « Increase Contrast » sur iOS et à « High contrast text » sur Android. Le flag n'est mis à jour que sur iOS 13+ et Android API 34+. MediaQuery.highContrastOf renvoie false en l'absence d'ancêtre MediaQuery. Sur desktop et web, il ne faut donc pas en dépendre seul.
  <https://api.flutter.dev/flutter/widgets/MediaQueryData/highContrast.html>
  ~ The Android wording in the doc is 'high contrast text' settings. The desktop/web advice is an inference, not stated by the doc.
- Flutter : MediaQueryData.disableAnimations reflète le réglage Android « Remove animations ». Sur iOS, le mouvement réduit passe par dart:ui AccessibilityFeatures.reduceMotion (iOS uniquement), qui ne positionne pas disableAnimations. Il faut donc traiter les deux signaux.
  <https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html>
  ~ Nuance : disableAnimations est lu depuis le moteur (SemanticsBinding). Une surcharge par MediaQuery n'affecte pas les animations du framework.
- Flutter : MediaQueryData.boldText indique que la plateforme demande un rendu du texte en gras. Il provient de PlatformDispatcher.accessibilityFeatures.
  <https://api.flutter.dev/flutter/widgets/MediaQueryData/boldText.html>
- L'API Guideline de flutter_test permet d'automatiser des contrôles d'accessibilité dans les tests de widgets, après tester.ensureSemantics(), via expectLater(tester, meetsGuideline(...)) : androidTapTargetGuideline (48x48), iOSTapTargetGuideline (44x44), labeledTapTargetGuideline et textContrastGuideline.
  <https://docs.flutter.dev/ui/accessibility/accessibility-testing>
  ~ The page's description adds 'for Android' (48x48) and 'for iOS' (44x44); sizes are logical pixels.
- La doc Flutter recommande au moins 4.5:1 pour le petit texte (moins de 18 pt normal ou 14 pt gras) et 3.0:1 pour le grand texte. Elle demande aussi de vérifier que la mise en page tient avec la plus grande taille de police de l'OS. Elle ne cite pas de seuil de 200 %, qui vient de WCAG 1.4.4.
  <https://docs.flutter.dev/ui/accessibility/ui-design-and-styling>
  ~ The doc's example is testing on a small-screen device set to the largest font setting.
## CONTESTED (0)
## KILLED (0)
## GAPS
- La page Understanding 2.5.8 ne cite pas le chiffre de 44 px. Ce chiffre a été lu dans le texte normatif de 2.5.5, sur w3.org/TR/WCAG22.
- Correction de nommage : 2.4.11 est 'Focus Not Obscured (Minimum)' (AA). 'Focus Appearance' est 2.4.13 (AAA) et ne relève pas de 2.4.11.
- Les seuils Lc d'APCA viennent seulement d'une source secondaire, le dépôt GitHub de l'auteur Myndex. Aucune page w3.org ne fixe de valeur Lc, et les tables tierces divergent (gihyo.jp, brainy.ink).
- Sur la page de textContrastGuideline, l'API Flutter ne précise pas les seuils numériques (renvoi au code source). La doc accessibility-testing ne cite que 3:1 pour le grand texte.
- La documentation MediaQueryData.boldText ne donne pas la correspondance avec chaque plateforme.
- L'absence de support de highContrast et reduceMotion sur desktop et web est déduite des notes de plateforme. Aucune page ne l'affirme explicitement.
- Aucun widget Semantics, ni API Semantics, n'a été vérifié dans cette passe.
- La doc Flutter recommande 48x48 pour toutes les cibles tactiles. C'est plus strict que WCAG 2.5.8 (24 px CSS) : il faudra choisir la norme interne du design system.

## Passe 2 — ai-ux

## KEPT (21)
- Cloudscape découpe le chargement d'une réponse d'IA générative en 2 étapes : 'processing' (le prompt est envoyé et aucune sortie n'existe encore) puis 'generation' (la sortie arrive alors que le traitement continue).
  <https://cloudscape.design/patterns/genai/genai-loading-states/>
- Cloudscape demande d'accompagner tout indicateur de chargement GenAI d'un texte de chargement visible qui décrit l'état en cours.
  <https://cloudscape.design/patterns/genai/genai-loading-states/>
- Cloudscape déconseille d'afficher un état de chargement pour une opération de moins d'une seconde, car cela crée un effet brusque et du scintillement. Si le streaming démarre presque tout de suite, il faut streamer directement.
  <https://cloudscape.design/patterns/genai/genai-loading-states/>
- Cloudscape réserve le streaming au texte et aux extraits de code inline. Pour les autres contenus, comme les tableaux et les blocs de code, il prescrit une barre de chargement.
  <https://cloudscape.design/patterns/genai/genai-loading-states/>
- Cloudscape emploie le libellé 'Generating' quand l'IA construit un contenu nouveau, et 'Loading' ou 'Fetching' quand elle récupère un contenu qui existe déjà. Les messages de chargement ne prennent pas de ponctuation finale.
  <https://cloudscape.design/patterns/genai/genai-loading-states/>
- Dans le pattern de régénération de Cloudscape, le bouton d'envoi devient un bouton Stop pendant la génération, ce qui permet de l'interrompre. Une fois la génération arrêtée, l'option Regenerate est disponible tout de suite.
  <https://cloudscape.design/patterns/genai/response-regeneration/>
- Chez Cloudscape, Regenerate s'affiche sous chaque réponse éligible et remplace la réponse d'origine par une alternative. Le système supprime alors tous les messages qui suivaient la réponse régénérée.
  <https://cloudscape.design/patterns/genai/response-regeneration/>
- Le chat GenAI de Cloudscape demande de lister les sources de la réponse ou de les citer inline avec des numéros [1], [2], [3] dans l'ordre. Il recommande aussi les pouces haut/bas pour recueillir le ressenti sur une réponse.
  <https://cloudscape.design/patterns/genai/generative-AI-chat/>
  ~ Nuance : les sources sont listées dans une section dépliable intitulée 'Sources'. Les boutons pouce s'intitulent 'Helpful' et 'Not helpful'.
  ~ Nuance: the sources go in an expandable section titled 'Sources'. The thumbs up/down buttons are labeled 'Helpful' and 'Not helpful', and the additional feedback is optional.
- Microsoft Research (Amershi et al., CHI 2019) propose 18 guidelines Human-AI Interaction. Elles ont été validées notamment par une étude où 49 praticiens du design les ont appliquées à 20 produits grand public intégrant de l'IA. Les auteurs préviennent que la revue de littérature dont elles sont tirées « may not be exhaustive ».
  <https://www.microsoft.com/en-us/research/wp-content/uploads/2019/01/Guidelines-for-Human-AI-Interaction-camera-ready.pdf>
- Voici les intitulés exacts des 18 guidelines HAX (G1 à G18) : Make clear what the system can do ; Make clear how well the system can do what it can do ; Time services based on context ; Show contextually relevant information ; Match relevant social norms ; Mitigate social biases ; Support efficient invocation ; Support efficient dismissal ; Support efficient correction ; Scope services when in doubt ; Make clear why the system did what it did ; Remember recent interactions ; Learn from user behavior ; Update and adapt cautiously ; Encourage granular feedback ; Convey the consequences of user actions ; Provide global controls ; Notify users about changes.
  <https://www.microsoft.com/en-us/research/wp-content/uploads/2019/01/Guidelines-for-Human-AI-Interaction-camera-ready.pdf>
- Le HAX Toolkit de Microsoft regroupe les guidelines en 4 phases d'interaction : au premier contact, pendant l'interaction, quand le système se trompe, et dans la durée.
  <https://www.microsoft.com/en-us/haxtoolkit/ai-guidelines/>
- Les Apple HIG (Generative AI) imposent de signaler clairement où et quand l'IA intervient, et de ne jamais laisser croire qu'un contenu ou un interlocuteur est humain s'il s'agit d'une IA.
  <https://developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json>
- Les Apple HIG demandent en général une confirmation avant toute action importante faite au nom de l'utilisateur. Elles déconseillent d'automatiser les actions destructrices ou difficiles à annuler, comme supprimer des photos ou faire un achat (human-in-the-loop).
  <https://developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json>
- Les Apple HIG recommandent de placer des contrôles comme Edit, Undo, Retry ou Adjust près du contenu généré, pour qu'on puisse l'affiner, l'annuler ou le relancer.
  <https://developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json>
- Les Apple HIG veulent que le feedback reste toujours volontaire, et suggèrent un moyen rapide de le donner, comme des boutons pouce haut / pouce bas. En cas d'erreur, il faut décrire ce qui s'est passé en langage simple et proposer une étape suivante claire.
  <https://developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json>
  ~ Nuance: the thumbs-up/thumbs-down advice is worded as 'Consider offering', so it is a suggestion, not a requirement.
- Les Apple HIG demandent d'annoncer clairement ce que la fonction IA sait faire ou non, et de dire explicitement que le contenu généré peut contenir des erreurs.
  <https://developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json>
- Le guidebook Google PAIR (Errors & Graceful Failure) recommande, quand le système IA échoue, de laisser l'utilisateur reprendre la main facilement. Il distingue trois types d'erreurs : les limites du système, les erreurs de contexte et les erreurs « background » que ni l'utilisateur ni le système ne détectent.
  <https://pair.withgoogle.com/chapter/errors-failing/>
- Le guidebook Google PAIR (Explainability & Trust) vise une confiance calibrée plutôt qu'aveugle. Il juge risqués les indicateurs de confiance numériques et demande d'indiquer quelle action l'utilisateur doit mener pour chaque niveau de confiance.
  <https://pair.withgoogle.com/chapter/explainability-trust/>
  ~ Nuance: the 'action for each confidence level' advice appears under categorical visualizations: 'Clearly indicate what action a user should take under each category of confidence.'
- Le guidebook Google PAIR (Feedback & Control) distingue le feedback implicite (les journaux d'usage) du feedback explicite. Il demande de permettre de refuser le partage de feedback implicite, ainsi que d'adapter, éditer ou désactiver la sortie de l'IA.
  <https://pair.withgoogle.com/chapter/feedback-controls/>
  ~ Nuance : la page dit 'product logs' et non 'usage logs'. Elle demande de permettre de refuser 'certain aspects' du partage de feedback implicite.
- Selon NN/g, des citations peuvent donner une fausse impression de fiabilité même quand elles sont invalides ou hors sujet. NN/g déconseille aussi les explications pas-à-pas qui suggèrent une certitude ou une transparence, ainsi que le langage anthropomorphique, au profit d'un langage factuel et neutre.
  <https://www.nngroup.com/articles/explainable-ai/>
  ~ Nuance : NN/g dit 'regardless of its validity'. Le cas 'hors sujet' est une extrapolation légère.
  ~ The NN/g article is dated 2025-12-12.
- Les guidelines voix de Meta définissent le barge-in comme la capacité de l'utilisateur à interrompre une réponse ou un prompt du système par sa propre parole. Elles demandent de rendre l'activation du micro clairement perceptible, par des earcons ou des indices conversationnels.
  <https://developers.meta.com/horizon/design/voice/>
  ~ Nuance : la définition de Meta parle de 'their own input', pas strictement de 'parole'.
  ~ Nuance: the exact definition says 'with their own input', and the page adds that this usually means talking over the system.
## CONTESTED (0)
## KILLED (0)
## GAPS
- La page HTML des Apple HIG 'Generative AI' n'a pas pu être lue (rendu JS). Les citations Apple viennent de l'endpoint JSON officiel developer.apple.com/tutorials/data/design/human-interface-guidelines/generative-ai.json.
- Affirmation non vérifiée n°6 : le chiffre 49 praticiens / 20 produits est confirmé par le PDF CHI 2019. En revanche, la mention 'non exhaustives' porte sur la revue de littérature ('the list we captured may not be exhaustive'), et non sur les guidelines elles-mêmes.
- Je n'ai trouvé chez Cloudscape aucune page qui parle d'ingress/egress. La page du chat GenAI ne contient pas ces termes.
- Je n'ai trouvé aucune source primaire lue sur l'affichage d'une transcription vocale visible ni sur un retour visuel d'écoute. Meta ne couvre que les earcons et les indices conversationnels.
- Aucun article NN/g sur les agents IA n'a été lu. Seul l'article 'Explainable AI in Chat Interfaces' a été lu, et NN/g est classé comme source secondaire.
- Aucune guidance Material 3 (m3.material.io) spécifique à l'IA n'a été recherchée ni lue.

## Passe 2 — atomic-governance

## KEPT (23)
- Atomic Design (Brad Frost) comporte cinq niveaux : atoms, molecules, organisms, templates et pages. Les atomes sont des éléments de base comme un label, un champ de saisie ou un bouton, qui cessent d'être fonctionnels si on les découpe davantage. Correction de l'affirmation 1 : dans l'analogie chimique, Frost appelle « plus petite unité fonctionnelle » l'atome, pas la molécule.
  <https://atomicdesign.bradfrost.com/chapter-2/>
- Chez Frost, une molécule est un groupe relativement simple d'éléments d'UI qui fonctionnent ensemble comme une unité (exemple : label + champ + bouton = formulaire de recherche). Frost la rattache au principe de responsabilité unique.
  <https://atomicdesign.bradfrost.com/chapter-2/>
- Chez Frost, un organisme est un composant d'UI relativement complexe, formé de molécules, d'atomes ou d'autres organismes. Il constitue une section distincte de l'interface, par exemple un en-tête.
  <https://atomicdesign.bradfrost.com/chapter-2/>
  ~ The page's header example combines a logo atom, a primary navigation molecule and a search form molecule.
- Chez Frost, un template est un objet de niveau page qui place des composants dans une mise en page et montre la structure du contenu. Une page est une instance d'un template remplie de contenu réel représentatif, qui sert à vérifier que le système tient.
  <https://atomicdesign.bradfrost.com/chapter-2/>
- Frost précise qu'Atomic Design n'est pas un processus linéaire : c'est un modèle mental pour travailler en même temps sur l'interface entière et sur ses parties.
  <https://atomicdesign.bradfrost.com/chapter-2/>
- Frost accepte d'autres taxonomies. Il cite la suggestion « elements, modules, components » et l'exemple de GE (Principles, Basics, Components). Selon lui, la taxonomie choisie doit surtout aider l'organisation à mieux communiquer.
  <https://atomicdesign.bradfrost.com/chapter-2/>
  ~ GE's full taxonomy is Principles, Basics, Components, Templates, Features, Applications. The claim truncates it to the first three terms.
- La doc Flutter (qui reflète Flutter 3.47) indique que le thème global est un ThemeData passé à MaterialApp.theme, qu'il fixe surtout colorScheme et textTheme, et qu'on le lit avec Theme.of(context). Ordre d'application des styles : style du widget, puis thèmes qui surchargent le parent, puis thème principal de l'app.
  <https://docs.flutter.dev/cookbook/design/themes>
- Pour surcharger le thème sur une partie de l'app, la doc Flutter recommande d'étendre le thème parent avec Theme(data: Theme.of(context).copyWith(...)) plutôt que de créer un ThemeData complet.
  <https://docs.flutter.dev/cookbook/design/themes>
- ThemeExtension<T> permet d'ajouter des tokens propres au design system dans ThemeData. On la sous-classe, on y définit des champs et on implémente copyWith et lerp ; lerp rend fluides les transitions entre thèmes. On l'enregistre via le paramètre extensions de ThemeData (ou de copyWith) et on la récupère avec la méthode extension.
  <https://api.flutter.dev/flutter/material/ThemeExtension-class.html>
  ~ The ThemeExtension class page itself covers only subclassing, fields, copyWith and lerp (smooth transitions). Registration through extensions and retrieval with extension<T>() are documented on the ThemeData.extensions page (see [9]), not on the cited page.
- ThemeData.extensions reçoit un Iterable de sous-classes de ThemeExtension, passé au constructeur ThemeData ou à copyWith.
  <https://api.flutter.dev/flutter/material/ThemeData/extensions.html>
- Un bouton Material comme FilledButton a trois couches de style : le défaut (defaultStyleOf), le thème (FilledButtonTheme dans un sous-arbre ou ThemeData.filledButtonTheme pour toute l'app) et le paramètre style du widget. Ses variantes passent par des constructeurs nommés (FilledButton.tonal, FilledButton.icon), pas par un enum.
  <https://api.flutter.dev/flutter/material/FilledButton-class.html>
  ~ There is also a FilledButton.tonalIcon constructor.
- Toutes les propriétés de ButtonStyle valent null par défaut ; une valeur absente retombe sur le défaut du bouton, dérivé du colorScheme et du textTheme. Beaucoup de propriétés sont des WidgetStateProperty, qui varient selon l'état (pressed, hovered, focused, disabled). styleFrom() permet des changements globaux, et merge comble les champs null avec ceux d'un autre style.
  <https://api.flutter.dev/flutter/material/ButtonStyle-class.html>
- L'aperçu d'architecture Flutter privilégie la composition : plutôt que de sous-classer Container, on compose des widgets. La hiérarchie de classes est volontairement peu profonde et large, faite de petits widgets qui font chacun une seule chose.
  <https://docs.flutter.dev/resources/architectural-overview>
- Effective Dart déconseille les paramètres booléens positionnels (AVOID positional boolean parameters) et recommande à la place des arguments nommés, des constructeurs nommés ou des constantes nommées. Cela s'applique directement aux variantes d'un widget de design system.
  <https://dart.dev/effective-dart/design>
  ~ Applying the guideline to design-system widget variants is the KB's own inference; the page does not say it.
  ~ The recommendation to use named constructors or arguments for widget variants is the knowledge base's own reading of the rule, not something Effective Dart says.
- En Dart, l'opérateur caret ^ s'arrête à la version majeure suivante pour une version >= 1.0, mais à la version mineure suivante pour une version < 1.0 : ^0.1.2 équivaut à '>=0.1.2 <0.2.0'.
  <https://dart.dev/tools/pub/dependencies>
- La convention Dart applique aussi le versionnage sémantique avant 1.0, avec un cran de décalage : passer de 0.1.2 à 0.2.0 est un changement cassant, 0.1.3 une nouvelle fonctionnalité, et 0.1.2+1 un changement sans effet sur l'API publique. Après 1.0, tout changement incompatible impose d'incrémenter la version majeure.
  <https://dart.dev/tools/pub/versioning>
- @Deprecated('migration') marque une fonctionnalité comme dépréciée, et le message doit expliquer comment obtenir le même effet autrement. La classe Deprecated a des constructeurs nommés ciblés : Deprecated.extend, .implement, .instantiate, .mixin, .optional et .subclass.
  <https://api.dart.dev/dart-core/Deprecated-class.html>
- L'équipe Flutter ne supprime pas les API dépréciées selon un calendrier fixe. Quand elle en supprime une, elle suit la même procédure que pour un changement cassant (annonce, notes de version, guide de migration).
  <https://docs.flutter.dev/release/compatibility-policy>
- Pour pub.dev, le CHANGELOG.md doit avoir une section titrée par version, tous les titres au même niveau (tous en niveau 1 ou tous en niveau 2), et chaque titre contient le numéro de version, éventuellement préfixé par « v ». Il s'affiche dans l'onglet Changelog du package.
  <https://dart.dev/tools/pub/package-layout>
- Les pub workspaces sont disponibles depuis Dart 3.6.0. Le pubspec.yaml racine liste les membres sous workspace:, et chaque membre déclare resolution: workspace avec une contrainte SDK ^3.6.0 ou plus. dart pub get produit un seul pubspec.lock à la racine (résolution partagée) et supprime ceux des membres.
  <https://dart.dev/tools/pub/workspaces>
  ~ dart pub get also creates a single shared .dart_tool/package_config.json and deletes the members' package_config.json files.
  ~ The root pubspec also needs a name, publish_to: none and an SDK constraint. pub get also deletes the members' .dart_tool/package_config.json files, not just their lock files.
- Melos (version 8.10.0 sur pub.dev) s'appuie désormais sur les pub workspaces. Le fichier melos.yaml n'existe plus : la configuration se place sous la clé melos: du pubspec.yaml racine, et les packages sont listés sous workspace:.
  <https://pub.dev/packages/melos>
- Le quick start Widgetbook fait créer une app Flutter séparée pour le catalogue (flutter create widgetbook --empty), renommée widgetbook_workspace dans son pubspec. Il utilise @widgetbook.App() et @widgetbook.UseCase(name: ..., type: <Composant>), puis dart run build_runner build -d, qui génère main.directories.g.dart.
  <https://docs.widgetbook.io/quick-start>
  ~ The catalog app is created inside the app's directory.
- Processus de gouvernance de Brad Frost : utiliser d'abord les composants existants, contacter tôt l'équipe design system, décider si un nouveau travail est nécessaire, trier entre snowflake et composant du système, prototyper, construire, documenter, publier en semver, puis adopter. Une snowflake (composant ponctuel propre à un seul produit) va dans le backlog de l'équipe produit concernée.
  <https://bradfrost.com/blog/post/a-design-system-governance-process/>
  ~ The article also includes review steps (review of the initial concept, formal design/dev and testing, final review with the product team). The claim condenses them.
  ~ The claim leaves out review steps. The actual list is: use existing components; contact the design system team; classify the work as snowflake or system; prototype; review the concept; formal design, development and testing in a feature branch; final review with the product team; document and stage; release under semver; product teams adopt and run QA.
## CONTESTED (0)
## KILLED (0)
## GAPS
- Affirmation 2 (praticien Flutter : trop de paramètres de constructeur à faire transiter entre couches) : aucune source trouvée ni lue, donc non incluse.
- Affirmation 3 (escamoteur et la sur-décomposition de widgets utilisés une seule fois) : la recherche n'a trouvé aucune page d'escamoteur sur ce sujet, donc non incluse.
- Affirmation 4 (Mix, « plus gros effort Atomic Design + tokens », coût d'apprentissage) : non vérifiée. La page pub.dev de Mix 2.3.1 ne dit que « An expressive way to effortlessly build design systems in Flutter » et parle de tokens via MixScope. Elle ne mentionne pas Atomic Design.
- Modèles d'équipe de Nathan Curtis (EightShapes : solitary, centralized, federated) : l'article Medium d'origine a renvoyé une erreur 403, et je n'ai vu que des extraits secondaires dans les résultats de recherche, donc non inclus.
- La page cookbook Flutter sur les thèmes ne mentionne ni ThemeExtension ni les component themes, et ne dit pas que Material 3 est le défaut. La syntaxe exacte Theme.of(context).extension<T>() n'est pas confirmée mot pour mot.
- L'ordre de priorité précis entre le paramètre style et FilledButtonTheme n'est pas énoncé explicitement sur la page API.
- Pas de source primaire lue sur le choix enum vs constructeurs nommés pour les variants, au-delà d'Effective Dart et de l'exemple FilledButton.tonal.
- Widgetbook : les numéros de version du quick start apparaissent comme gabarits ({{ versions.widgetbook }}). Les versions 3.25.0 et 4.0.0-beta.14 n'ont pas été revérifiées sur pub.dev, et je n'ai pas lu de recommandation Widgetbook sur les pub workspaces.
- La page pub.dev de Melos ne dit pas explicitement que Melos 7 exige les workspaces, et elle n'affiche pas de date de publication absolue.
- Je n'ai pas cherché de critique primaire d'Atomic Design sur la sur-décomposition.

## Passe 2 — color

## KEPT (24)
- Dans Flutter, ColorScheme.fromSeed utilise par défaut dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot. Cette variante produit des palettes pastel peu colorées, même quand la graine a une forte chroma.
  <https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html>
- Si le schéma tonalSpot paraît trop terne ou trop sombre, la doc de fromSeed recommande DynamicSchemeVariant.fidelity, dont les palettes correspondent à la couleur graine.
  <https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html>
  ~ The doc only says 'If the resulting color scheme is too dark'. It says nothing about the scheme being too dull ('trop terne'). Remove 'terne' or present it as an interpretation.
  ~ Nuance: the doc only names the case where the scheme is 'too dark'. 'Trop terne' (too dull) is an extrapolation, though it is consistent with the pastel description.
- DynamicSchemeVariant propose tonalSpot, fidelity, monochrome, neutral, vibrant, expressive, content, rainbow et fruitSalad. Avec content, primaryContainer est la graine ajustée pour le contraste. Avec expressive, la teinte primaire diffère de la graine. Avec rainbow et fruitSalad, la teinte de la graine n'apparaît pas dans le thème.
  <https://api.flutter.dev/flutter/material/DynamicSchemeVariant.html>
- Le paramètre contrastLevel de fromSeed va de -1.0 (contraste le plus bas) à 1.0 (le plus haut), avec 0.0 par défaut. Selon les guidelines Material, 0.5 correspond au contraste moyen et 1.0 au contraste élevé.
  <https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html>
- Tout rôle optionnel non nul passé à ColorScheme.fromSeed (par exemple primary:) remplace la couleur générée pour ce rôle. Par construction de l'algorithme, la seedColor peut n'apparaître dans aucun rôle du schéma.
  <https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html>
- ColorScheme.background est déprécié depuis v3.18.0-0.1.pre au profit de surface. ColorScheme.surfaceVariant est déprécié depuis la même version au profit de surfaceContainerHighest.
  <https://api.flutter.dev/flutter/material/ColorScheme/surfaceVariant.html>
- M3 définit 26 rôles de couleur standards répartis en six groupes : primary, secondary, tertiary, error, surface et outline.
  <https://m3.material.io/styles/color/roles>
  ~ Nuance: the same page also has 'add-on' roles (fixed, surface dim/bright, and others) beyond the 26 standard roles.
- M3 n'assure un contraste accessible que si l'on utilise les couleurs dans les paires ou ordres de superposition prévus, par exemple onPrimary sur primary. Une combinaison libre de rôles peut casser le contraste.
  <https://m3.material.io/styles/color/roles>
- Dans M3, les rôles *Container servent de remplissage aux éléments de premier plan, comme les boutons. Ils ne doivent pas servir à colorer du texte ou des icônes : pour cela, on utilise onXContainer.
  <https://m3.material.io/styles/color/roles>
- M3 définit cinq surface containers : surfaceContainerLowest, surfaceContainerLow, surfaceContainer (le rôle par défaut), surfaceContainerHigh et surfaceContainerHighest. Dans Flutter, ces surfaces tonales remplacent l'ancien modèle de teinte superposée selon l'élévation.
  <https://api.flutter.dev/flutter/material/ColorScheme-class.html>
  ~ The Flutter page lists the containers along with surfaceBright and surfaceDim. It does not say which container is the default. 'Surface container is the default role' comes from m3.material.io/styles/color/roles.
  ~ Nuance: Flutter also lists surfaceBright and surfaceDim among the tone-based surfaces.
- outline sert aux frontières importantes, comme le contour d'un champ texte. outlineVariant sert aux éléments décoratifs comme les séparateurs. Pour délimiter une cible ou créer une hiérarchie visuelle, M3 demande outline ou une couleur offrant un contraste de 3:1 avec la surface.
  <https://m3.material.io/styles/color/roles>
- Les rôles primaryFixed, secondaryFixed et tertiaryFixed (et leurs variantes *FixedDim) gardent le même ton en clair et en sombre. Pour cette raison, M3 déconseille de les utiliser là où le contraste est nécessaire.
  <https://m3.material.io/styles/color/roles>
- M3 définit quatre rôles d'erreur : error, onError, errorContainer et onErrorContainer.
  <https://m3.material.io/styles/color/roles>
- Material Color Utilities (MCU) définit HCT (hue, chroma, tone), un espace colorimétrique fondé sur CAM16 et L*. La bibliothèque est publiée en Dart sur pub.dev sous le nom material_color_utilities. Ses modules incluent blend, contrast, dislike, dynamiccolor, hct, palettes, quantize, scheme, score et temperature.
  <https://github.com/material-foundation/material-color-utilities>
  ~ Nuance: the README also lists a utilities module.
- Dans le modèle HCT de M3, le ton va de 0 (noir) à 100 (blanc). La teinte va de 0 à 360. La chroma plafonne en pratique vers 120.
  <https://m3.material.io/styles/color/system/how-the-system-works>
- Pour intégrer une couleur custom ou statique (sémantique, par exemple) dans un schéma dynamique, M3 propose une fonction optionnelle « harmonize ». Elle rapproche la teinte de la couleur statique de celle de la primaire, dans une amplitude limitée pour préserver son sens : un rouge reste rouge, sans virer au violet ni à l'orange.
  <https://m3.material.io/styles/color/advanced/adjust-existing-colors>
- M3 recommande de ne pas harmoniser les couleurs dont l'apparence doit rester strictement constante, comme les couleurs de marque. Pour figer une marque, il propose plutôt de définir son propre schéma de base à partir des couleurs d'entrée primary, secondary, tertiary, neutral et neutral variant.
  <https://m3.material.io/styles/color/advanced/adjust-existing-colors>
  ~ The page does not tie the two pieces of advice together with a 'plutôt' (instead). The 'Define your own baseline scheme' section stands on its own: it is for colors that stay static 'such as to reflect your brand colors'. It first lists primary, secondary, tertiary and neutral as inputs, then adds neutral variant in the 'How' section (Theme Builder).
  ~ Nuance: the page does not link the two points with 'plutôt' (instead). It recommends a custom baseline scheme so colors stay static 'such as to reflect your brand colors', using the Theme Builder with primary, secondary, tertiary, neutral and neutral variant as inputs.
- En Dart (MCU), Blend.harmonize(designColor, sourceColor) décale la teinte HCT de la couleur vers celle de la couleur source. Le code limite cette rotation à min(différence × 0.5, 15°).
  <https://raw.githubusercontent.com/material-foundation/material-color-utilities/main/dart/lib/blend/blend.dart>
- Harmonies classiques : les complémentaires sont opposées sur le cercle chromatique et donnent le contraste maximal. Les triades sont équidistantes (triangle équilatéral). Le split-complémentaire remplace l'une des complémentaires par deux couleurs analogues voisines. L'analogue associe une couleur racine et des voisines ; c'est l'harmonie la plus stable.
  <https://en.wikipedia.org/wiki/Harmony_(color)>
  ~ Wikipedia is a secondary source. It also says 'two or more nearby colors' for analogous colors.
- Plutôt que des angles fixes sur un cercle HSL, MCU fournit TemperatureCache. Ses méthodes analogous({count = 5, divisions = 12}) et complement s'appuient sur la température de couleur (chaud/froid) et non sur la seule rotation de teinte.
  <https://raw.githubusercontent.com/material-foundation/material-color-utilities/main/dart/lib/temperature/temperature_cache.dart>
- Dans SchemeTonalSpot (MCU Dart), la primaire garde la teinte de la graine avec une chroma de 36. La secondaire garde aussi cette teinte, avec une chroma de 16. La tertiaire tourne de +60° avec une chroma de 24. Le neutral a une chroma de 6. M3 dérive donc les accents d'une seule graine au lieu d'appliquer une harmonie complémentaire ou triadique.
  <https://raw.githubusercontent.com/material-foundation/material-color-utilities/main/dart/lib/scheme/scheme_tonal_spot.dart>
  ~ Exact values: neutralVariant has chroma 8. These constants come from the classic SchemeTonalSpot on the main branch.
  ~ Nuance: the neutral variant uses chroma 8.
- Mode sombre M3 : dans MCU, surface (et background) prend le ton 6 en sombre contre 98 en clair, donc pas de noir pur (ton 0). Primary prend le ton 80 en sombre contre 40 en clair.
  <https://raw.githubusercontent.com/material-foundation/material-color-utilities/main/dart/lib/dynamiccolor/material_dynamic_colors.dart>
  ~ Exception: in the monochrome variant, primary is tone 100 in dark and 0 in light.
  ~ Nuance: primary is 80/40 except for the monochrome variant (100 dark / 0 light). Some containers, such as surfaceContainerLowest in dark mode at high contrast, can reach tone 0.
- Les rôles M3 gèrent trois niveaux de contraste (standard par défaut, medium, high), appliqués automatiquement en clair comme en sombre. Les composants custom en profitent s'ils utilisent les bons rôles, par exemple primaryContainer et onPrimaryContainer.
  <https://m3.material.io/styles/color/system/how-the-system-works>
- CSS Color 4 définit oklch(L C H) : L va de 0 % à 100 % (0.0 à 1.0) ; pour C, 100 % équivaut à 0.4, et C dépasse rarement 0.5 en pratique. Oklab est plus perceptuellement uniforme que CIE Lab. En HSL, au contraire, changer la teinte modifie la luminosité perçue.
  <https://www.w3.org/TR/css-color-4/>
  ~ The spec says C 'in practice does not exceed 0.5'. That is stronger than 'rarely'. The statement that Oklab is more uniform than CIE Lab appears in the section on color difference.
## CONTESTED (0)
## KILLED (0)
## GAPS
- Les rôles d'erreur « statiques » (une erreur qui ne suit pas la couleur dynamique) n'apparaissent pas sur la page m3 roles telle que lue. Seuls les 4 rôles d'erreur sont confirmés.
- La revérification 6 est corrigée : M3 dit que les paires de rôles offrent un minimum de 3:1, et non 4.5:1. outlineVariant convient aux éléments décoratifs « when other elements provide 4.5:1 contrast ».
- Je n'ai trouvé aucune page m3.material.io dédiée au thème sombre (par exemple « éviter le noir pur »). L'affirmation sur le mode sombre repose sur les tons de MCU (surface 6 en sombre).
- La page Flutter ColorScheme-class mentionne un contraste recommandé de 4.5:1 entre une couleur et sa couleur « on ». Cette citation passe par le résumé de WebFetch et n'est pas incluse.
- Je n'ai pas lu l'API Flutter pour un équivalent natif de harmonize. Blend.harmonize vient du package material_color_utilities, et je n'ai pas vérifié la version exacte de ce package livrée avec Flutter 3.47.
- Les lignes MCU citées viennent de la branche main au 2026-10-27. Les versions récentes de MCU (spec 2025) peuvent déléguer à d'autres fichiers ; à revérifier avant de figer des chiffres.
- Wikipedia est une source secondaire pour les harmonies classiques. Je n'ai trouvé aucune page d'aide officielle Adobe Color.

## Passe 2 — desktop-flutter

## KEPT (30)
- Pour intégrer un contrôle custom au parcours Tab, la doc Flutter recommande FocusableActionDetector, qui réunit dans un seul widget le focus, l'entrée souris (hover) et les raccourcis clavier (actions + bindings + callbacks de surbrillance).
  <https://docs.flutter.dev/ui/adaptive-responsive/input>
- Le widget Shortcuts ne déclenche ses raccourcis que si son sous-arbre (ou un descendant) a le focus et est visible ; il faut donc envelopper le sous-arbre dans un Focus (par ex. Focus(autofocus: true)).
  <https://docs.flutter.dev/ui/adaptive-responsive/input>
  ~ Nuance: the page does not explicitly say to wrap the subtree in Focus(autofocus: true). That is an inference from the focus requirement, which the official Shortcuts and CallbackShortcuts examples also follow.
- Un listener statique global HardwareKeyboard n'est pas géré par le framework : c'est au développeur de le désactiver quand l'utilisateur tape dans un champ ou quand le widget associé est masqué (cas critique : raccourci Delete/Backspace avec des TextField enfants).
  <https://docs.flutter.dev/ui/adaptive-responsive/input>
- Dans Shortcuts, LogicalKeySet est remplacé par l'interface ShortcutActivator ; SingleActivator prend une seule touche plus des modificateurs optionnels (ex. const SingleActivator(LogicalKeyboardKey.arrowUp)).
  <https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts>
- CallbackShortcuts (bindings: Map<ShortcutActivator, VoidCallback>) est l'alternative légère quand on n'a besoin que de callbacks, sans la flexibilité Intent/Action ; l'exemple officiel l'enveloppe aussi d'un Focus(autofocus: true).
  <https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts>
- Shortcuts résout l'Intent via Actions.invoke depuis le contexte du Focus, en remontant les widgets Actions ancêtres jusqu'à trouver le type d'Intent ; une Action n'est invoquée que si isEnabled(intent) renvoie true ; Actions.maybeInvoke combine recherche et invocation.
  <https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts>
  ~ Nuance : si l'action trouvée n'est pas enabled, le framework arrête là sa recherche au lieu de remonter plus haut.
  ~ Nuance: the doc describes maybeInvoke only as the single-call form of maybeFind plus invokeAction, and it returns null if no action is found.
- Bonne pratique Intents : ne pas mettre dans l'Intent un état commun à toutes les invocations d'une Action ; cet état va dans le constructeur de l'Action.
  <https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts>
- La politique de parcours par défaut est ReadingOrderTraversalPolicy ; pour un ordre explicite on utilise OrderedTraversalPolicy (avec FocusTraversalOrder), et FocusTraversalGroup délimite des sections du sous-arbre parcourues comme un groupe.
  <https://docs.flutter.dev/ui/interactivity/focus>
- Ne pas allouer un FocusNode à chaque build (fuites mémoire, perte de focus au rebuild) : le créer dans le State d'un StatefulWidget et le disposer dans dispose().
  <https://docs.flutter.dev/ui/interactivity/focus>
- Ne pas partager un même FocusNode entre plusieurs widgets : ils se disputent ses attributs.
  <https://docs.flutter.dev/ui/interactivity/focus>
- autofocus : au plus un widget par focus scope (sinon le choix est arbitraire), et il n'agit que si le scope n'a pas déjà un focus.
  <https://docs.flutter.dev/ui/interactivity/focus>
- Les key events partent du nœud au focus primaire et remontent vers la racine tant que KeyEventResult.handled n'est pas renvoyé ; ils sont traités avant la saisie texte, donc un handler autour d'un TextField peut avaler la touche.
  <https://docs.flutter.dev/ui/interactivity/focus>
  ~ Nuance: an event that reaches the root unhandled is returned to the platform.
- FocusManager expose highlightMode et highlightStrategy : la stratégie bascule automatiquement entre mode « touch » et « traditional » (souris/clavier) selon les derniers événements d'entrée, ou peut être verrouillée sur l'un des deux.
  <https://docs.flutter.dev/ui/interactivity/focus>
- Changer le curseur dans un widget custom se fait avec MouseRegion(cursor: SystemMouseCursors.click) ; les boutons Material gèrent le focus, sauf si on met overlayColor à transparent, auquel cas il faut implémenter et tester soi-même l'état de focus.
  <https://docs.flutter.dev/ui/adaptive-responsive/input>
  ~ Nuance: the page states the overlayColor exception, but the conclusion 'implement and test focus yourself' is implied rather than spelled out in the excerpt I checked.
- VisualDensity est sans unité, horizontal/vertical à 0.0 par défaut (l'exemple utilise -1.0 hors mode tactile) ; Material utilise environ 4 px logiques par unité de densité.
  <https://docs.flutter.dev/ui/adaptive-responsive/input>
  ~ Nuance : l'exemple de la page utilise 1 unité = 6 pixels ; 4 px est la valeur Material générale.
  ~ Nuance: the doc's own example uses 1 unit = 6 px ('totally up to you'), while Material uses about 4 px per unit.
- VisualDensity.adaptivePlatformDensity renvoie VisualDensity.compact quand defaultTargetPlatform est desktop, et un VisualDensity par défaut sur les autres plateformes.
  <https://api.flutter.dev/flutter/material/VisualDensity/adaptivePlatformDensity.html>
- Sur desktop, la plupart des Scrollable reçoivent une Scrollbar par défaut via ScrollBehavior.buildScrollbar (ScrollConfiguration) ; pour un pouce toujours visible, thumbVisibility: true, ce qui exige un ScrollController (controller ou PrimaryScrollController).
  <https://api.flutter.dev/flutter/material/Scrollbar-class.html>
- Tooltip.waitDuration (délai de survol avant affichage) vaut 0 ms par défaut : le tooltip apparaît immédiatement au survol ; exitDuration règle le délai de masquage après la fin du survol.
  <https://api.flutter.dev/flutter/material/Tooltip/waitDuration.html>
  ~ Le comportement de exitDuration n'est pas décrit sur la page waitDuration citée : vérifier sur Tooltip/exitDuration.html.
- Les widgets Flutter ne sont pas sélectionnables par défaut ; envelopper le body de la route dans SelectionArea crée une zone sélectionnable avec contrôles adaptatifs (contextMenuBuilder pour la barre d'outils).
  <https://api.flutter.dev/flutter/material/SelectionArea-class.html>
- Sur web, le menu contextuel du navigateur est actif par défaut et ceux de Flutter masqués ; BrowserContextMenu.disableContextMenu() le désactive (no-op hors web).
  <https://api.flutter.dev/flutter/services/BrowserContextMenu-class.html>
- ContextMenuController (show/remove/removeAny statique) garantit qu'un seul menu contextuel est affiché à la fois dans toute l'app.
  <https://api.flutter.dev/flutter/widgets/ContextMenuController-class.html>
- MenuBar et SubmenuButton créent leur propre MenuAnchor ; MenuAnchor (menuChildren, MenuController) sert hors MenuBar, par ex. pour un menu contextuel en cascade.
  <https://api.flutter.dev/flutter/material/MenuAnchor-class.html>
- PlatformMenuBar (menus natifs) n'est supporté d'origine que sur macOS ; les autres plateformes dépendent de plugins qui définissent WidgetsBinding.platformMenuDelegate.
  <https://api.flutter.dev/flutter/widgets/PlatformMenuBar-class.html>
- Classes de taille de fenêtre (largeur) : compact <600dp, medium 600–839, expanded 840–1199, large 1200–1599, extra-large ≥1600 (desktop).
  <https://developer.android.com/develop/ui/compose/layouts/adaptive/window-size-classes>
  ~ Source Android Developers (pas Flutter/M3) ; les bornes sont identiques.
  ~ Nuance: on Android, the large and extra-large classes require supportLargeAndXLargeWidth = true.
- Choisir la mise en page selon la taille de fenêtre disponible, jamais selon le type d'appareil ; Material conseille une barre de navigation inférieure sous 600 px logiques et une NavigationRail à partir de 600.
  <https://docs.flutter.dev/ui/adaptive-responsive/general>
- MediaQuery.sizeOf sert pour la taille de la fenêtre entière, LayoutBuilder pour les contraintes données par le parent (taille locale d'un widget).
  <https://docs.flutter.dev/ui/adaptive-responsive/general>
- Préférer MediaQuery.sizeOf(context) à MediaQuery.of(context).size : le contexte ne se reconstruit que quand la taille change.
  <https://api.flutter.dev/flutter/widgets/MediaQuery/sizeOf.html>
- flutter_adaptive_scaffold est discontinué (dernière version 0.3.3+1) ; ne pas l'adopter pour un nouveau design system.
  <https://pub.dev/packages/flutter_adaptive_scaffold>
- super_drag_and_drop (0.9.1 stable, 0.10.0-dev.2 en préversion) fournit le drag & drop natif entre applications sur Android, iOS, Linux, macOS, Web et Windows ; sur web, le drag sortant reste limité au même onglet.
  <https://pub.dev/packages/super_drag_and_drop>
- Au 24/08/2026, l'API multi-fenêtres desktop (WindowController/Window, DialogWindowController/DialogWindow) n'existe que sur le canal main, derrière le flag expérimental flutter config --enable-windowing, et peut encore changer.
  <https://flutter.dev/blog/desktop-windowing-apis>
  ~ Nuance: at 2026-10-27 I found no official announcement of a stable release; secondary sources from August 2026 still describe the API as main-channel only, behind a flag.
## CONTESTED (0)
## KILLED (0)
## GAPS
- Les docs input/actions-and-shortcuts ne citent pas OrderedTraversalPolicy avec NumericFocusOrder/LexicalFocusOrder : seule OrderedTraversalPolicy est confirmée (page focus). Les classes FocusTraversalOrder, NumericFocusOrder et LexicalFocusOrder n'ont pas été vérifiées sur api.flutter.dev.
- Tooltip : seule la valeur par défaut de waitDuration (0 ms) a été lue. Les défauts de showDuration, exitDuration et triggerMode n'ont pas été vérifiés.
- La page m3.material.io des window size classes a renvoyé une erreur 404 (rendu JS). Les seuils viennent de developer.android.com (doc Google officielle), pas de m3.material.io.
- La page NavigationRail indique « typically between three and five » destinations et recommande BottomNavigationBar en portrait. NavigationDrawer n'a pas été vérifié.
- SelectableText et SelectionContainer.disabled n'ont pas été vérifiés.
- Non vérifiés : la version exacte de Flutter stable qui embarquerait le multi-fenêtres, et les plateformes supportées une par une. Une source tierce dit que le stable 3.47.5 ne propose pas --enable-windowing, sans confirmation primaire.
- La page actions-and-shortcuts ne mentionne pas FocusableActionDetector. Cette affirmation repose sur adaptive-responsive/input.
- Mode TooltipTriggerMode, MouseRegion onEnter/onExit et le hover (survol) n'ont pas été vérifiés en détail sur api.flutter.dev.

## Passe 2 — desktop-guidelines

## KEPT (25)
- Windows recommande des accélérateurs clavier homogènes entre applications. La table « Common Keyboard Accelerators » donne notamment : Undo = Ctrl+Z, Redo = Ctrl+Y, Select all = Ctrl+A, Rename = F2, Refresh = F5 ou Ctrl+R, Save = Ctrl+S, Close = Ctrl+W, Find = Ctrl+F, Zoom par défaut = Ctrl+0, volet suivant/précédent = F6/Shift+F6.
  <https://learn.microsoft.com/en-us/windows/apps/design/input/keyboard-accelerators>
- Côté Windows, il faut définir des accélérateurs pour les actions les plus courantes et les documenter dans le libellé de l'élément de menu ou dans le tooltip, par exemple « Copy (Ctrl+C) ». Les menus servent aux utilisateurs à découvrir les commandes.
  <https://learn.microsoft.com/en-us/windows/apps/design/input/keyboard-accelerators>
- Windows recommande de limiter la portée des accélérateurs d'un menu contextuel au parent de ce menu (raccourci « scoped »). Les autres accélérateurs restent globaux à l'application. Exemple Outlook : Ctrl+B ne fonctionne que dans le formulaire d'envoi, Ctrl+1 dans toute l'app.
  <https://learn.microsoft.com/en-us/windows/apps/design/input/keyboard-accelerators>
  ~ Nuance: an accelerator is global by default (ScopeOwner null) unless a ScopeOwner is set. The page says this applies in general, not only to accelerators that are not in context menus. In the Outlook example, Ctrl+B, Ctrl+I and Esc work in the send email form; Ctrl+1 and Ctrl+2 work app-wide.
  ~ Small nuance: in the Outlook example, Ctrl+B, Ctrl+I and Esc work only in the send email form, and Ctrl+1 and Ctrl+2 work app-wide. Accelerators are global by default when ScopeOwner is null.
- Windows recommande de localiser les accélérateurs clavier. Certaines combinaisons ne valent pas dans toutes les langues : dans le Windows espagnol, Ctrl+N sert au gras à la place de Ctrl+B.
  <https://learn.microsoft.com/en-us/windows/apps/design/input/keyboard-accelerators>
- Sous Windows, une access key est la touche Alt suivie d'un ou plusieurs caractères alphanumériques, pressés en séquence. Appuyer sur Alt affiche des badges « keytips ». Il faut préférer un seul caractère, ne pas dépasser deux caractères, éviter les collisions dans une même portée et éviter les caractères ambigus (I/1, O/0).
  <https://learn.microsoft.com/en-us/windows/apps/design/input/access-keys>
- D'après Windows, le clavier doit être un mode d'interaction principal : tout élément activable au pointeur doit l'être aussi au clavier, au minimum avec Espace et Entrée sur les contrôles invocables.
  <https://learn.microsoft.com/en-us/windows/apps/design/accessibility/keyboard-accessibility>
  ~ Exact wording: 'should be treated as a primary interaction model, not a secondary fallback'.
- Windows recommande F6 pour passer d'une grande région de l'application à l'autre (barre d'adresse, onglets, contenu), et Shift+F6 pour parcourir ce cycle en sens inverse. Cette navigation n'est pas fournie automatiquement : il faut l'implémenter explicitement.
  <https://learn.microsoft.com/en-us/windows/apps/design/accessibility/keyboard-accessibility>
  ~ Nuance: the regions in the Edge example are the address bar, bookmark bar, tab strip and content.
- Windows préconise qu'un contrôle composite (liste, grille, arbre) occupe un seul arrêt de tabulation. On navigue entre ses enfants avec les flèches. Dans un arbre, flèche gauche et flèche droite replient et déplient.
  <https://learn.microsoft.com/en-us/windows/apps/design/accessibility/keyboard-accessibility>
  ~ Nuance: the page describes 'a common pattern' (the root stays in the tab order and active descendants are managed internally), not a strict rule. For trees, left/right arrows map to collapse/expand only 'where expand/collapse and activation are separate interactions'.
  ~ Nuance: the page presents a single tab stop as 'a common pattern', not a strict rule. The left/right arrows for collapse/expand appear in the custom controls section ('In tree scenarios where expand/collapse and activation are separate interactions').
- Les « high visibility focus visuals » de Windows ont deux bordures : une bordure primaire extérieure de 2px et une bordure secondaire intérieure de 1px, avec une marge par défaut de 1px autour des limites du contrôle. Les propriétés FocusVisualPrimaryThickness, FocusVisualSecondaryThickness et FocusVisualMargin permettent de les personnaliser.
  <https://learn.microsoft.com/en-us/windows/apps/design/input/guidelines-for-visualfeedback>
- Windows distingue menu et menu contextuel. Un menu s'ouvre par clic gauche depuis un bouton ou une barre de menus. Un menu contextuel s'ouvre par clic droit (ou appui long), est attaché à un élément unique et ne contient que des commandes secondaires. Une commande fréquente gagne à être placée directement dans l'UI plutôt que dans un menu.
  <https://learn.microsoft.com/en-us/windows/apps/design/controls/menus-and-context-menus>
- Les tooltips Windows s'affichent au survol, au focus clavier ou à l'appui long. Il faut les utiliser avec parcimonie et les garder concis. Ils ne doivent pas répéter un texte déjà visible ni contenir de contrôles interactifs. Ils sont en revanche nécessaires pour les boutons de barre d'outils qui n'affichent qu'une icône.
  <https://learn.microsoft.com/en-us/windows/apps/design/controls/tooltips>
- Windows préconise des espacements standards : 8epx entre boutons, 8epx entre un bouton et son flyout, 12epx entre un contrôle et son libellé, 12epx entre zones de contenu et 16epx entre une surface et le texte en bordure.
  <https://learn.microsoft.com/en-us/windows/apps/design/basics/content-basics>
  ~ Nuance: the page also lists 8epx between a control and its header.
  ~ Additional value on the page: 8epx between a control and its header.
- Fluent 2 fonde son échelle d'espacement globale sur une unité de base de 4 px. L'échelle contient aussi quelques valeurs hors multiples de 4.
  <https://fluent2.microsoft.design/layout>
  ~ The values that are not multiples of 4 are 2, 6 and 10 (size20, size60, size100). They account for padding in Fluent icons.
  ~ The non-multiples of 4 are 2, 6 and 10. Fluent explains they account for the padding of Fluent icons.
- Fluent 2 demande que l'ordre de focus suive un parcours en « Z » (de gauche à droite, puis de haut en bas) et que le focus ne soit pas perdu à la fermeture d'une UI temporaire comme une boîte de dialogue. Les composants interactifs et non textuels doivent avoir un contraste d'au moins 3:1.
  <https://fluent2.microsoft.design/accessibility>
- Apple HIG (macOS) : ne pas détourner les raccourcis standards pour des actions personnalisées. Pour plusieurs modificateurs, les afficher dans l'ordre Control, Option, Shift, Command. Préférer Command comme modificateur principal et Shift comme secondaire, réserver Option aux commandes rares et éviter Control, que le système utilise déjà.
  <https://developer.apple.com/design/human-interface-guidelines/keyboards>
  ~ Apple says 'In general' not to repurpose standard shortcuts, and allows it when the action makes no sense in the app.
- Dans la table des raccourcis standards de l'Apple HIG, Command-Virgule ouvre la fenêtre de réglages de l'app, Command-Q quitte l'app, Command-A sélectionne tout, Command-F ouvre la recherche et Command-Point annule une opération.
  <https://developer.apple.com/design/human-interface-guidelines/keyboards>
- Apple HIG : placer Undo et Redo en tête du menu Edit, avec les raccourcis Command-Z et Shift-Command-Z. Ne pas limiter inutilement le nombre d'annulations. Rendre visible le résultat de chaque undo/redo et en préciser la cible dans le libellé (par exemple « Undo Typing »).
  <https://developer.apple.com/design/human-interface-guidelines/undo-and-redo>
- Apple HIG (barre de menus) : toujours afficher le même ensemble d'éléments de menu. Un élément inutilisable dans le contexte courant est désactivé plutôt que masqué. Il faut aussi conserver les menus système et leur ordre, et prendre en charge les raccourcis des éléments standards (Copy, Cut, Paste, Save, Print).
  <https://developer.apple.com/design/human-interface-guidelines/the-menu-bar>
- Apple HIG (menus) : ajouter des points de suspension (…) au libellé d'un élément de menu quand l'action demande une saisie supplémentaire. Limiter les sous-menus à un seul niveau et envisager un nouveau menu au-delà d'environ cinq éléments.
  <https://developer.apple.com/design/human-interface-guidelines/menus>
- Apple HIG (drag and drop) : proposer toujours une alternative au glisser-déposer, par exemple des commandes de menu. Permettre d'annuler un dépôt. Afficher l'image de glissement dès environ 3 points de déplacement. Indiquer si la destination accepte le contenu. Un dépôt dans le même conteneur déplace le contenu, un dépôt dans un autre conteneur le copie.
  <https://developer.apple.com/design/human-interface-guidelines/drag-and-drop>
  ~ Nuance: Apple says 'Offer alternative ways' and 'Prefer letting people undo'. These are recommendations, so 'always' overstates them slightly. The move/copy rule is given 'as a general rule'.
  ~ Nuance: Apple says 'Prefer letting people undo' (a preference, not a requirement) and move versus copy is 'a general rule'. The Option key forces a copy within the same container.
- Flutter : VisualDensity.adaptivePlatformDensity renvoie VisualDensity.compact sur les plateformes desktop et la densité par défaut ailleurs. VisualDensity.compact vaut VisualDensity(horizontal: -2.0, vertical: -2.0), et une unité de densité correspond à environ 4 px logiques dans les composants Material.
  <https://api.flutter.dev/flutter/material/VisualDensity/adaptivePlatformDensity.html>
  ~ Nuance: the VisualDensity class doc calls density 'unitless'. The 4 logical pixel interval comes from the baseSizeAdjustment implementation ('four pixel increments', interval = 4.0), not from the page cited.
- La doc Flutter sur les entrées adaptatives recommande, sur desktop, MouseRegion (avec SystemMouseCursors.click) pour les curseurs et les effets de survol, Shortcuts + Actions pour les raccourcis limités au sous-arbre focalisé, et FocusableActionDetector pour réunir focus, survol et raccourcis dans un contrôle personnalisé.
  <https://docs.flutter.dev/ui/adaptive-responsive/input>
  ~ Nuance: only the cursor guidance is explicitly framed 'On desktop'. FocusableActionDetector is presented generically for custom controls. Shortcuts fire only when the subtree has focus and is visible.
  ~ Nuance: the scoping comes from the Shortcuts widget (it fires only when its subtree has focus and is visible). Actions maps intents to handlers.
- Flutter : PlatformMenuBar (menus natifs) n'est pris en charge d'origine que sur macOS. Sur les autres plateformes, sans plugin qui définit WidgetsBinding.platformMenuDelegate, le widget n'a aucun rendu et ne fait que renvoyer son enfant.
  <https://api.flutter.dev/flutter/widgets/PlatformMenuBar-class.html>
  ~ Nuance: on all platforms, the widget 'has no visual representation, and intercepts no events: it just returns the child from its build'. On platforms other than macOS, without a delegate, no native menu is created.
- Le package fluent_ui est en version 4.17.0, publiée le 2026-10-19 par bdlukaa.dev (éditeur vérifié). Il exige Dart >=3.8.0 et Flutter >=3.32.0. Un seul mainteneur l'entretient activement.
  <https://pub.dev/packages/fluent_ui>
- Le package macos_ui est en version 2.2.2, publiée le 2025-10-19, soit environ 12 mois sans nouvelle version au 2026-10-27. Il exige Dart >=3.9.2 et Flutter >=3.35.0.
  <https://pub.dev/packages/macos_ui/versions>
  ~ The only prerelease is 2.0.0-beta.11, which is older (about 3 years). No newer version exists.
## CONTESTED (0)
## KILLED (0)
## GAPS
- Les pages de l'Apple HIG sont rendues en JavaScript, et WebFetch n'en lisait que le titre. Je les ai lues via leur endpoint JSON officiel (developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json). Les citations viennent de ce JSON, pas du HTML rendu.
- Pas d'affirmation sourcée sur la mémorisation de la taille et de la position des fenêtres. La page HIG windows lue ne contient pas de consigne explicite sur la restauration, et je n'ai pas trouvé de page Windows équivalente.
- Les tailles Standard 40x40 epx et Compact 32x32 epx de Windows, ainsi que Compact.xaml, ne sont pas retenues : l'URL design/style/spacing redirige maintenant vers content-basics, qui n'en parle plus. Seuls des résumés de recherche le mentionnent.
- Fluent 2 (fluent2.microsoft.design) ne dit rien d'exploitable sur la densité compacte, les menus ou les commandes dans les pages lues (layout, accessibility, design-principles). Les pages composants Fluent 2 (Menu, Tooltip, Toolbar) n'ont pas été lues.
- Pas d'affirmation primaire sur la sélection multiple (Shift-clic pour une plage, Ctrl/Cmd-clic pour un ajout) sur Windows ou macOS. La page HIG pointing-devices ne traite que la sélection par rectangle sur iPadOS.
- Pas de source primaire lue sur des états hover/focus/pressed distincts en dehors des focus visuals Windows et de MouseRegion dans Flutter. Les états d'interaction Material 3 (m3.material.io) n'ont pas été consultés.
- La gestion Ctrl/Cmd multiplateforme dans Flutter (SingleActivator avec meta vs control, ou LogicalKeySet) n'est pas couverte par la page docs.flutter.dev lue.
- La maintenance de macos_ui (activité du dépôt GitHub, issues) n'a pas été vérifiée au-delà de la date de la dernière version.

## Passe 2 — genui-ux

## KEPT (22)
- Dans genui, un `Catalog` est l'ensemble des `CatalogItem` que l'IA a le droit d'utiliser. `SurfaceController` accepte plusieurs catalogues pour regrouper les widgets de façon logique.
  <https://docs.flutter.dev/ai/genui/components>
- Un `CatalogItem` genui associe trois éléments : un `name` (le nom que le LLM référence), un `dataSchema` (schéma des propriétés) et un `widgetBuilder` qui construit le widget Flutter.
  <https://docs.flutter.dev/ai/genui/get-started>
- Le schéma d'un `CatalogItem` se définit avec le package `json_schema_builder` (`S.object`, `S.string(description: ...)`, `required`). Le LLM lit les `description` de chaque propriété, il faut donc les rédiger pour lui.
  <https://docs.flutter.dev/ai/genui/get-started>
  ~ Nuance: the S.object / S.string(description:) / required example is confirmed, but the page never says the LLM reads the descriptions. That part is a reasonable inference, not something the doc states.
  ~ Nuance: the doc shows S.string(description:) but does not explicitly say that the LLM reads the descriptions; that is an implicit deduction (the schema is injected into the prompt).
- `BasicCatalogItems` (texte, markdown, images) sert au démarrage, mais la doc recommande un catalogue sur mesure en production. L'exemple étend le catalogue de base avec `BasicCatalogItems.asCatalog().copyWith(newItems: [...])`.
  <https://docs.flutter.dev/ai/genui/get-started>
- Le prompt système se construit avec `PromptBuilder.chat(catalog:, systemPromptFragments:)`. Il doit dire explicitement au LLM d'utiliser les outils UI fournis par `SurfaceController`, et le prompt généré peut dépasser 3 000 à 5 000 tokens, ce qui est trop pour les petits modèles.
  <https://docs.flutter.dev/ai/genui/get-started>
- La doc genui ne montre aucune API de thème dédiée. Les widgets du catalogue prennent leur style dans le thème de l'app via `Theme.of(itemContext.buildContext)`, par exemple `textTheme.headlineMedium`. Pour que les surfaces générées suivent le design system, il faut donc que les builders lisent le `ThemeData` (ou les ThemeExtension) de l'app.
  <https://docs.flutter.dev/ai/genui/get-started>
  ~ Nuance: the exact code is Theme.of(context) with context = itemContext.buildContext. Recommending that builders read ThemeData/ThemeExtension is a design inference.
  ~ Nuance: Theme.of(context) appears only in the RiddleCard example code, with no accompanying prose. 'No dedicated theme API' is an observation about the doc, not a statement from it.
- Pour gérer plusieurs surfaces, on écoute `Conversation.events` (événements `ConversationSurfaceAdded` / `ConversationSurfaceRemoved`, qui portent un `surfaceId`). On rend ensuite un widget `Surface(surfaceContext: surfaceController.contextFor(id))` par surface active.
  <https://docs.flutter.dev/ai/genui/get-started>
- Le `DataModel` genui est un store observable et centralisé. Quand une donnée change, seuls les widgets liés à ce chemin sont reconstruits. Les saisies utilisateur (un champ texte, par exemple) mettent à jour le DataModel sans appel à l'agent.
  <https://docs.flutter.dev/ai/genui/components>
  ~ Nuance: the page says the interaction 'directly updates the DataModel' and only actions create a UserMessage. 'Without calling the agent' is inferred from that contrast.
  ~ Nuance: the doc says the interaction 'directly updates the DataModel'; only actions (button clicks) create a UserMessage to the agent. 'Without calling the agent' is implied, not stated word for word.
- Une action utilisateur (un clic sur un bouton, par exemple) remonte à l'agent selon ce chemin : le widget appelle `itemContext.dispatchEvent(UserActionEvent(name:, sourceComponentId:, context:))`, `Surface` injecte le `surfaceId`, puis `SurfaceController.handleUiEvent` enveloppe l'événement en JSON `{'action': ...}` et l'émet sur le flux `onSubmit`, que `Conversation` écoute.
  <https://docs.flutter.dev/ai/genui/input-events>
  ~ Precision: onSubmit emits a UserUiInteractionMessage.text(jsonEncode({'action': ...})), and Conversation subscribes with onSubmit.listen(sendRequest).
  ~ Detail: what is emitted on onSubmit is a UserUiInteractionMessage.text(jsonEncode({'action': ...})); Conversation subscribes via surfaceController.onSubmit.listen(sendRequest).
- En streaming côté genui, il faut passer les morceaux de texte du LLM à `A2uiTransportAdapter.addChunk()`. Cet adaptateur les convertit en `A2uiMessage` pour le `SurfaceController`.
  <https://pub.dev/packages/genui>
  ~ Detail: the adapter produces TextEvents or A2uiMessageEvents (text plus A2UI messages).
- Sécurité A2UI : le format est déclaratif et non exécutable. Le client tient un catalogue de composants de confiance pré-approuvés, et l'agent ne peut demander que des composants de ce catalogue.
  <https://github.com/google/A2UI>
- La responsabilité de la sécurité incombe au développeur : c'est à lui d'imposer un sandboxing strict dans ses composants personnalisés.
  <https://github.com/google/A2UI>
  ~ Nuance: the exact wording is 'places security firmly in the developer's hands, enabling them to enforce strict sandboxing policies'. That describes a capability, not an explicit obligation limited to custom components.
- Statut d'A2UI : la version de production est la v0.9.1, la v1.0 est release candidate et la v0.8 est legacy. Le projet est en preview publique précoce.
  <https://github.com/google/A2UI>
- A2UI recommande qu'une app de production définisse son propre catalogue, qui reflète directement son design system, plutôt que d'adapter le Basic Catalog au design system.
  <https://a2ui.org/concepts/catalogs/>
  ~ Nuance: you can import selected Basic Catalog definitions into your own catalog.
- Négociation de catalogue A2UI : dans les métadonnées de chaque message, le client envoie `supportedCatalogIds`, classés par ordre de préférence. L'agent choisit un catalogue, le fige pour toute la vie de la surface et l'annonce dans le `catalogId` de `createSurface`. Sans catalogue compatible, l'agent n'envoie aucune UI.
  <https://a2ui.org/concepts/catalogs/>
- Il faut versionner un catalogue A2UI comme une API : les ajouts sont sans risque, on marque `deprecated: true` au lieu de supprimer, et un changement cassant donne lieu à une version majeure inscrite dans l'URI du `catalogId` (v1 vers v2).
  <https://a2ui.org/concepts/catalogs/>
  ~ Add the detail: deprecated: true goes with x-deprecated-reason.
  ~ Detail: add x-deprecated-reason and keep renderer support; during migration, clients can advertise v1 and v2.
- Le style des surfaces A2UI est contrôlé par le renderer et le thème relève de l'implémentation du catalogue. L'agent envoie des indications sémantiques (`usageHint`), jamais de styles visuels. Les composants du Basic Catalog ignorent le `theme` transmis par l'agent dans `createSurface`.
  <https://a2ui.org/guides/theming/>
  ~ Nuance: the theming guide still says 'usageHint' (v0.8 terminology), but in the v0.9.1 spec the Text component uses 'variant' (h2, caption...). The principle (semantic hints, no visual styles) stands.
- Rendu progressif A2UI (v0.9.1) : les composants arrivent en liste plate, en liste d'adjacence liée par id, avec exactement un composant d'id `root`. Le rendu peut commencer dès que `root` est défini, et `updateComponents` ajoute ou met à jour des composants de façon incrémentale.
  <https://a2ui.org/specification/v0.9.1-a2ui/>
  ~ Nuance: updates received before root are buffered.
- UX du streaming A2UI : on diffuse en JSONL et le rendu est progressif, de sorte que l'utilisateur voit l'UI se construire plutôt qu'un spinner. On préfère des mises à jour granulaires du modèle de données (`/user/name` plutôt que `/`).
  <https://a2ui.org/concepts/data-flow/>
- Gestion d'erreurs A2UI : le client valide les messages de l'agent. En cas d'échec, il renvoie un message `error` (code `VALIDATION_FAILED`, avec le surfaceId et un JSON Pointer vers le champ fautif) pour que le LLM se corrige au tour suivant (boucle prompt, generate, validate).
  <https://a2ui.org/specification/v0.9.1-a2ui/>
  ~ Nuance: the spec says 'the client (or the system acting on behalf of the client)'. Validation can therefore happen agent-side in the prompt-generate-validate loop, not necessarily in the client renderer. The format also requires a 'message' field.
- Validation côté client A2UI : un bouton peut définir des `checks`. Si l'un d'eux échoue, le bouton est désactivé automatiquement et un message d'erreur précis peut être affiché.
  <https://a2ui.org/specification/v0.9.1-a2ui/>
  ~ Nuance: the spec ties the specific error messages to the checks of input components rather than to the button itself.
  ~ Nuance: the error message is carried by each check's 'message' field; the spec does not specify how a disabled button displays it.
- A2UI n'envoie le modèle de données au serveur que lorsqu'un message client vers serveur est déclenché (une action, par exemple), et uniquement au serveur qui a créé la surface. Avec `sendDataModel: true` dans `createSurface` (false par défaut), le modèle complet part dans les métadonnées de chaque message.
  <https://a2ui.org/specification/v0.9.1-a2ui/>
  ~ Clarification: sending the data model happens only when sendDataModel is true (false by default). It is then sent with client-to-server messages (actions) in the a2uiClientDataModel metadata, and only to the server that created the surface. Without sendDataModel, only the resolved action context is sent.
## CONTESTED (1)
- Le package genui est en alpha et son API est susceptible de changer. La dernière version publiée sur pub.dev est la 0.10.4, environ 28 jours avant le 2026-10-27.
  <https://pub.dev/packages/genui>
  ~ The version part is right: pub.dev lists 0.10.4 as the latest version, published 28 days ago. The quoted sentence is missing from pub.dev/packages/genui, though. It appears on https://docs.flutter.dev/ai/genui under an 'Experimental' heading. Change the source_url.
  ~ Exact: 0.10.4 is the latest on pub.dev and was published on Sep 29, 2026, i.e. 28 days ago. The 'alpha' warning, however, does not appear on the pub.dev page as fetched; it comes from docs.flutter.dev/ai/genui ('The genui package is in alpha and is likely to change.'). Fix the source of the citation.
  ! Refetching pub.dev/packages/genui found none of the words alpha, 'likely to change' or experimental, so the citation is not on the cited source.
## KILLED (0)
## GAPS
- La doc Flutter genui ne décrit aucune API de thème dédiée aux surfaces générées : le thème n'apparaît qu'à travers Theme.of(context) dans les builders. Le DESIGN.md (github.com/flutter/genui/.../DESIGN.md) a renvoyé une 404 et n'a pas pu être lu.
- Aucune doc lue ne traite des états de chargement côté genui (isWaiting/isProcessing, indicateurs) : à vérifier dans le code source ou l'API dartdoc.
- Incohérence de nommage : docs.flutter.dev/ai/genui/components cite les messages createSurface, surfaceUpdate, dataModelUpdate et deleteSurface (noms v0.8), alors que la spec A2UI v0.9.1 parle d'updateComponents et d'updateDataModel. Il faut vérifier quelle version d'A2UI genui 0.10.4 implémente.
- Pour les erreurs, genui dit seulement que les erreurs déclenchent des callbacks sur Conversation, sans en donner les noms. Les noms exacts des callbacks sont à vérifier dans l'API.
- Le format exact du message error de la spec A2UI (noms de champs comme path et message) a été résumé par l'outil, pas cité mot pour mot.
- Le batching d'environ 16 ms et le diffing décrits sur a2ui.org/concepts/data-flow ont été résumés, pas cités : ils sont exclus des affirmations.
- L'annonce A2UI sur le blog Google Developers n'a pas été consultée.
- Aucune guidance officielle détaillée n'existe sur la rédaction des descriptions de composants pour le LLM, en dehors des description de json_schema_builder et du conseil de prompting one-shot ou few-shot.

## Passe 2 — tokens-pipeline

## KEPT (23)
- Style Dictionary prend en charge le format DTCG de façon native depuis sa v4. Le format 2025.10 n'y est pas encore entièrement supporté : la doc indique que ce travail est en cours pour la v5.
  <https://styledictionary.com/info/dtcg/>
- Au 2026-10-27, la dernière version npm de style-dictionary est 5.7.1, publiée le 2026-10-24. La v5.0.0 date du 2025-05-16 et la v4.0.0 du 2024-06-28. La v5.7.0 ajoute le support des valeurs `duration` du DTCG 2025.10.
  <https://github.com/style-dictionary/style-dictionary/releases>
  ~ The release page shows dates without the year. The full dates come from the npm registry: 5.7.1 on 2026-10-24, 5.7.0 on 2026-10-16, 5.0.0 on 2025-05-16 and 4.0.0 on 2024-06-28. The duration support is in v5.7.0.
  ~ Nuance : la v5.7.0 date du 2026-10-16. La 5.7.1 est un correctif de sécurité (prototype pollution, GHSA-m4pr-rgwp-x36r).
- L'option de config `usesDtcg` de Style Dictionary n'a généralement pas besoin d'être définie : l'outil détecte seul le format DTCG.
  <https://styledictionary.com/reference/config/>
- Style Dictionary fournit le format intégré `flutter/class.dart`, qui génère une classe Dart de valeurs. Il accepte les options `showFileHeader` (true par défaut), `outputReferences` (false par défaut) et `className`, et la classe générée importe package:flutter/material.dart.
  <https://styledictionary.com/reference/hooks/formats/predefined/>
  ~ No default is listed for className.
  ~ Nuance : la doc ne donne pas de valeur par défaut pour `className`. L'exemple produit `class StyleDictionary` avec un constructeur privé.
- Les transformGroups prédéfinis `flutter` et `flutter-separate` de Style Dictionary appliquent les mêmes six transforms : attribute/cti, name/camel, color/hex8flutter, size/flutter/remToDouble, content/flutter/literal et asset/flutter/literal. `flutter-separate` sert à générer un fichier par catégorie, sans le préfixe de catégorie dans les noms.
  <https://styledictionary.com/reference/hooks/transform-groups/predefined/>
- Le transform `color/hex8flutter` produit un objet Flutter `Color` en hex 8 chiffres, alpha en tête. `size/flutter/remToDouble` multiplie la valeur par 16, ou par `basePxFontSize` s'il est défini sur la plateforme. Aucun transform `color/*` de Style Dictionary ne mentionne OKLCH.
  <https://styledictionary.com/reference/hooks/transforms/predefined/>
- Dans Style Dictionary, `log.errors.brokenReferences` vaut 'throw' par défaut : une référence cassée est donc fatale. `log.warnings` vaut 'warn' par défaut et peut être mis à 'error' pour qu'un avertissement, par exemple une collision de tokens, fasse échouer le build en CI.
  <https://styledictionary.com/reference/logging/>
- Style Dictionary permet de définir un format personnalisé avec `StyleDictionary.registerFormat({ name, format({ dictionary, platform, options, file }) })`. On peut s'en servir pour générer un `ThemeExtension` Flutter plutôt que la classe statique par défaut.
  <https://styledictionary.com/reference/hooks/formats/>
  ~ The page does not mention ThemeExtension; that use is the author's own idea, which is fine as a suggestion.
  ~ Nuance : le ThemeExtension est un usage proposé par la note, pas un exemple tiré de la doc.
- La spécification DTCG Format 2025.10 a été publiée le 28 octobre 2025 comme Final Community Group Report et se déclare stable. Elle recommande les extensions `.tokens` ou `.tokens.json` et le type MIME `application/design-tokens+json`.
  <https://www.designtokens.org/tr/2025.10/format/>
  ~ The status section also says the spec was published 'as a Candidate Recommendation'.
  ~ Nuance : l'en-tête indique « Final Community Group Report », mais la section de statut parle encore de « Candidate Recommendation ». Le document lui-même est incohérent.
- Le DTCG 2025.10 définit sept types de base (color, dimension, fontFamily, fontWeight, duration, cubicBezier, number) et six types composites (strokeStyle, border, transition, shadow, gradient, typography). Il définit aussi `$deprecated`, les références JSON Pointer via `$ref` et l'héritage de groupes via `$extends`. Les alias `{a.b}` ne visent que des tokens complets.
  <https://www.designtokens.org/tr/2025.10/format/>
  ~ The exact text is 'Tools MUST support JSON Pointer references as defined by RFC 6901 ... using the $ref property'. The quote paraphrases it.
- Dans le DTCG 2025.10, la `$value` d'un token couleur est un objet. Il contient `colorSpace` (obligatoire), `components` (obligatoire), `alpha` (optionnel, 1 par défaut) et `hex` (repli optionnel en hex 6 chiffres). Les espaces de couleur pris en charge incluent `oklch`, `oklab`, `display-p3`, `srgb` et `rec2020`.
  <https://www.designtokens.org/tr/2025.10/color/>
  ~ The spec also includes srgb-linear, hsl, hwb, lab, lch, a98-rgb, prophoto-rgb, xyz-d65 and xyz-d50.
  ~ Nuance : la liste complète compte aussi srgb-linear, hsl, hwb, lab, lch, a98-rgb, prophoto-rgb, xyz-d65 et xyz-d50.
- Le module Resolver du DTCG 2025.10 décrit les contextes (thèmes ou modes clair, sombre, contraste élevé). Il s'appuie sur des `sets`, des `modifiers` et un tableau `resolutionOrder`, et les documents qu'il décrit portent l'extension `.resolver.json`.
  <https://www.designtokens.org/tr/2025.10/resolver/>
  ~ Nuance : l'extension .resolver.json est recommandée, pas obligatoire. Le champ version vaut "2025.10".
- Flutter (dart:ui) accepte des couleurs Display P3 via `Color.from(alpha:, red:, green:, blue:, colorSpace: ColorSpace.displayP3)`. Sur une plateforme sans support P3, ces couleurs sont ramenées à sRGB. `ColorSpace` ne propose que sRGB, extendedSRGB et displayP3, sans OKLCH.
  <https://api.flutter.dev/flutter/dart-ui/ColorSpace.html>
  ~ The ColorSpace page does not document the Color.from constructor; that comes from the Color class page.
- Terrazzo est le nouveau nom de Cobalt, né en 2021 comme outillage du format DTCG. Ses docs affirment qu'il est le seul outil à supporter tout le format DTCG. Ses resolvers acceptent `version: 2025.10` et succèdent aux « modes » hérités de Cobalt.
  <https://terrazzo.app/docs/guides/resolvers/>
  ~ The cited resolvers page backs only the quote and version: 2025.10. The rename from Cobalt, the 2021 start and the claim of being the only tool with full DTCG support come from other Terrazzo pages (/docs/reference/about and /docs/). The 'only tool' line is the vendor's own claim.
  ~ Nuance : l'affirmation « seul outil » est une auto-déclaration de Terrazzo. La page docs contient encore la parenthèse « support for resolvers ... coming in 2.0 », alors que la CLI est déjà en 2.x.
- Au 2026-10-27, @terrazzo/cli est en version 2.10.0 (publiée le 2026-10-21). Les plugins officiels publiés sur npm sont css, sass, js, css-in-js, tailwind, vanilla-extract, swift et token-listing : il n'existe pas de plugin Dart/Flutter officiel. Les docs listent les intégrations CSS, Sass, JS/TS, Swift, Tailwind, etc.
  <https://terrazzo.app/docs/>
  ~ The docs also list Storybook and Vanilla Extract.
  ~ Nuance : la page docs liste aussi Storybook et Custom parmi les intégrations.
- Pour une sortie Dart, Terrazzo n'offre que son Plugin API, avec les hooks `config`, `lint`, `transform` (setTransform) et `build` (getTransforms, outputFile), plus `buildEnd`. Le plugin choisit librement le nom de son format.
  <https://terrazzo.app/docs/reference/plugin-api/>
  ~ The page also mentions buildFile(filename, contents) in one description, which conflicts with outputFile.
  ~ Nuance : transform et build reçoivent aussi `resolver` et `sources`, et buildEnd reçoit `outputFiles` et `ast`. L'option `enforce` (pre/post) existe aussi.
- Tokens Studio permet de choisir entre le format « legacy » (par défaut) et le format W3C DTCG, qui préfixe $value, $type et $description. En DTCG, les caractères `{`, `}` et `$` sont interdits dans les noms de tokens. Le format peut être changé à tout moment, et le plugin convertit alors les JSON.
  <https://docs.tokens.studio/manage-settings/token-format>
- Tokens Studio synchronise les tokens dans les deux sens avec GitHub (push et pull). La synchronisation multi-fichiers, avec un fichier JSON par Token Set plus le fichier de thèmes, est une fonction Pro, et les membres sans licence Pro n'ont qu'un accès en lecture seule.
  <https://docs.tokens.studio/token-storage/remote/sync-git-github>
- Figma importe et exporte nativement les modes de variables en JSON au format DTCG, avec un fichier par mode. À l'import, les couleurs doivent être en sRGB ou HSL, les dimensions en `px` et les durées en `s`. Un booléen s'exprime par `$extensions` com.figma.type: "boolean", et les noms imbriqués sont convertis en chemins séparés par des slashs.
  <https://help.figma.com/hc/en-us/articles/15343816063383-Modes-for-variables>
  ~ Nuance: the page states the DTCG format only for import. For export it says 'export variable modes to a JSON file' without naming DTCG. 'One file per mode' is stated for import ('A new mode will be created for each file you import').
  ~ Nuance : « un fichier par mode » n'est vérifié que pour l'import (chaque fichier importé crée un mode). L'article ne précise pas la forme de l'export. Les booléens sont des tokens number avec $extensions com.figma.type "boolean" (0 vaut false).
- L'API REST Variables de Figma (GET local variables et POST variables, scopes file_variables:read et file_variables:write) est réservée aux plans Enterprise. Elle exige un siège Full dans une org Enterprise, et les invités ne peuvent pas l'utiliser.
  <https://developers.figma.com/docs/rest-api/variables/>
  ~ Nuance: GET is open to any member of the Enterprise org with view access, while POST requires a Full seat or admin role.
  ~ Nuance : selon la page, GET reste ouvert à tout membre d'une org Enterprise ayant l'accès en lecture au fichier. POST exige un siège Full, le rôle admin et l'accès en écriture.
- Dans l'API plugin Figma, le `codeSyntax` d'une variable (affiché en Dev Mode) ne prend en charge que les plateformes 'WEB', 'ANDROID' et 'iOS', sans plateforme Flutter.
  <https://developers.figma.com/docs/plugins/api/Variable/>
- Figma Code Connect exige un siège Dev ou Full sur un plan Professional, Organization ou Enterprise. Les « template files », agnostiques du framework, sont désormais son format principal. Les guides par parser (React, HTML, SwiftUI, Compose) sont classés « Legacy », et aucune page ne mentionne Flutter.
  <https://developers.figma.com/docs/code-connect/template-files/>
  ~ The seat and plan requirements are on the Code Connect overview page, not the template-files page. The Professional plan is limited to one active framework.
  ~ Nuance : la doc développeurs inclut le plan Professional (une seule bibliothèque et un seul framework actifs). Le centre d'aide et le support Figma parlent eux d'Organization ou Enterprise seulement, et un post de forum du 2026-10-23 signale des mappings refusés sur Professional : il faut le vérifier. Les guides Legacy couvrent aussi Web components et Storybook.
- Flutter fournit `ThemeExtension`, une interface qui ajoute des données personnalisées (typiquement des couleurs) à `ThemeData`. Il faut implémenter `copyWith` et `lerp`, ce dernier assurant une transition fluide lors d'un changement de thème. C'est une cible naturelle pour des tokens sémantiques multi-modes.
  <https://api.flutter.dev/flutter/material/ThemeExtension-class.html>
  ~ The page does not mention tokens; using it as a token target is the author's own reading.
## CONTESTED (0)
## KILLED (0)
## GAPS
- Je n'ai trouvé aucune page officielle Figma qui détaille l'export DTCG natif : quel espace de couleur est exporté, si les alias sont conservés, si les descriptions sont incluses. Les seules sources sont un blog vendeur (atomize.tools) et un fil du forum Figma de fin 2025, signalant un déploiement progressif et l'absence des descriptions.
- Je n'ai pas trouvé la page officielle de la v5 de Style Dictionary qui suivrait le support des objets couleur DTCG 2025.10 ou du module Resolver. Les notes de version consultées ne parlent ni du resolver ni de Flutter.
- Je n'ai pas vérifié que le transform color/hex8flutter accepte en entrée un objet couleur DTCG 2025.10 (colorSpace/components). Il faudra probablement un transform personnalisé, en particulier pour l'OKLCH.
- Flutter n'a pas d'espace de couleur OKLCH : il faut convertir les tokens OKLCH en sRGB ou Display P3 au moment de la génération. C'est une déduction, je n'ai pas lu de source qui le dit.
- Code Connect pour Flutter/Dart : rien n'est documenté. Les template files sont « framework-agnostic », mais aucune valeur `language` Dart n'est confirmée.
- Je n'ai pas lu la page Getting Started de Terrazzo dans sa version la plus récente. Elle disait que le resolver arriverait en 2.0, alors que la CLI est déjà en 2.10.0 et que le guide resolvers existe : la page est donc probablement datée.
- Recommandations sur la source de vérité (dépôt Git en DTCG), la génération en CI et le contrôle de fraîcheur (régénérer puis `git diff --exit-code`) : ce sont des pratiques déduites, qu'aucune source primaire lue ne prescrit.

## Passe 2 — typo-space-motion

## KEPT (21)
- Le TextTheme Flutter expose les 15 noms M3 : displayLarge/Medium/Small, headlineLarge/Medium/Small, titleLarge/Medium/Small, bodyLarge/Medium/Small et labelLarge/Medium/Small. Les tailles M3 (2021), en px logiques, sont 57/45/36, 32/28/24, 22/16/14, 16/14/12 et 14/12/11.
  <https://api.flutter.dev/flutter/material/TextTheme-class.html>
  ~ Nuance : la citation H1-H6 concerne le tableau de la spec 2018. La page API affiche aussi les tailles 2018 par défaut (96/60/48...). En M3, les tailles effectives viennent de Typography.material2021 / englishLike2021 (57/45/36...).
- Les noms TextTheme de 2018 (headline1, bodyText1, caption, button, overline…) étaient dépréciés depuis Flutter 3.1. Ils ont été supprimés avec les dépréciations de Flutter 3.19 (PR #139255). Correspondances : headline1→displayLarge, bodyText1→bodyLarge, caption→bodySmall, button→labelLarge, overline→labelSmall.
  <https://docs.flutter.dev/release/breaking-changes/3-19-deprecations>
- Tokens de référence de l'échelle M3 (material-web v0_192) : display-large = 3.5625rem (57px) avec une hauteur de ligne de 4rem (64px), body-medium = 0.875rem/1.25rem (14/20px), label-small = 0.6875rem/1rem (11/16px). Les styles title-medium/small et label-* ont une graisse medium ; les autres sont en regular.
  <https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-typescale.scss>
  ~ Les poids du fichier sont des références (weight-regular/weight-medium), pas des valeurs numériques. label-large et label-medium ont aussi un token weight-prominent qui pointe vers weight-bold.
- Depuis la mise à jour Expressive, l'échelle de types M3 compte 30 styles : 15 de base (baseline) et 15 accentués (emphasized, md.sys.typescale.emphasized.*). Les composants Material n'utilisent pas les styles accentués par défaut.
  <https://m3.material.io/styles/typography/type-scale-tokens>
- Pour personnaliser l'échelle M3, Material conseille de changer les typefaces brand/plain, la hauteur de ligne et l'interlettrage, mais d'éviter de modifier les tailles, car cela affecte le rendu et le reflow des composants.
  <https://m3.material.io/styles/typography/type-scale-tokens>
  ~ La page ajoute de répéter ces ajustements pour les styles baseline et emphasized.
- M3 recommande une hauteur de ligne d'environ 1,2 × la taille pour title, headline et display, et d'environ 1,5 × la taille pour body et label.
  <https://m3.material.io/styles/typography/applying-type>
  ~ Nuance: for title/headline/display the page says 'a line height ratio of 1.2 times', with no 'around'. 'Around' is used only for 1.5.
  ~ Pour title/headline/display, la page écrit « a line height ratio of 1.2 times », sans « environ ». Les tokens réels s'en écartent (57/64 ≈ 1.12, 14/20 ≈ 1.43).
- Longueur de ligne lisible : à tous les breakpoints, M3 demande d'ajuster marges et styles de texte pour garder 40 à 60 caractères par ligne.
  <https://m3.material.io/foundations/layout/breakpoints/overview>
- Le système d'espacement M3 repose sur une échelle de 8dp (token space100 = 8dp), et non de 4dp. Material ne définit que les valeurs recommandées et privilégie padding et gaps sur le conteneur parent plutôt que des marges sur les enfants.
  <https://m3.material.io/styles/spacing/overview>
  ~ Le fait de privilégier padding et gaps du parent plutôt que les marges des enfants n'apparaît pas tel quel dans la vue d'ensemble. La page applique les tokens aux marges, paddings et gaps.
- L'échelle de coins M3 (après Expressive) compte 10 niveaux : none 0dp, extra-small 4dp, small 8dp, medium 12dp, large 16dp, large-increased 20dp, extra-large 28dp, extra-large-increased 32dp, extra-extra-large 48dp, full (entièrement arrondi).
  <https://m3.material.io/styles/shape/corner-radius-scale>
  ~ Les tokens material-web v0_192 ne comptent que 7 niveaux (sans large-increased, extra-large-increased ni extra-extra-large). La spec m3 est plus récente que ces tokens.
- Pour imbriquer des formes arrondies, M3 recommande « l'arrondi optique » : rayon intérieur = rayon extérieur − padding (par exemple 48dp − 14dp = 34dp). Il ne faut pas réutiliser le même rayon pour le parent et l'enfant.
  <https://m3.material.io/styles/shape/corner-radius-scale>
- Les niveaux d'élévation M3 0 à 5 valent 0, 1, 3, 6, 8 et 12dp. Par exemple, le niveau 3 (6dp) sert aux dialogues modaux et au FAB, le niveau 1 (1dp) aux cartes et boutons elevated.
  <https://m3.material.io/styles/elevation/tokens>
  ~ Le niveau 3 couvre aussi date/time pickers, extended FAB et search. Le niveau 1 couvre aussi banner, bottom sheet modal, chips elevated et drawer modal. Les niveaux 4 et 5 ne sont assignés comme niveau de repos à aucun composant.
- Les tokens material-web v0_192 confirment les valeurs d'élévation level0..level5 = 0, 1, 3, 6, 8, 12. L'unité n'est pas précisée dans le fichier.
  <https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-elevation.scss>
- Depuis Flutter 3.22.0 stable, le surfaceTintColor par défaut de tous les widgets est null. Le fond se base désormais sur les nouveaux rôles de surface tonaux (surfaceContainer*), qui remplacent l'ancien overlay teinté proportionnel à l'élévation.
  <https://docs.flutter.dev/release/breaking-changes/new-color-scheme-roles>
  ~ Landed in 3.21.0-4.0.pre ; stable 3.22.0.
- Material.surfaceTintColor n'applique un overlay, dont l'opacité dépend de l'élévation, que si useMaterial3 est vrai et que la couleur n'est ni null ni Colors.transparent. Sinon, aucune teinte n'est appliquée.
  <https://api.flutter.dev/flutter/material/Material/surfaceTintColor.html>
- La classe Flutter Durations (material) fournit les durées M3 : short1–4 = 50/100/150/200ms, medium1–4 = 250/300/350/400ms, long1–4 = 450/500/550/600ms, extralong1–4 = 700/800/900/1000ms.
  <https://api.flutter.dev/flutter/material/Durations-class.html>
- La classe Flutter Easing (material) expose emphasizedAccelerate, emphasizedDecelerate, standard, standardAccelerate, standardDecelerate, legacy*, linear. Elle n'a pas de constante « emphasized » : la spec M3 désigne Curves.easeInOutCubicEmphasized (un ThreePointCubic) pour l'easing emphasized en Flutter.
  <https://m3.material.io/styles/motion/easing-and-duration/tokens-specs>
- Valeurs Flutter : Easing.standard = Cubic(0.2, 0.0, 0.0, 1.0), Easing.emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0), Easing.emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15).
  <https://api.flutter.dev/flutter/material/Easing/standard-constant.html>
- Avec M3 Expressive, les composants et le mouvement passent à un système physique à ressorts (springs). Le système easing + durée sert encore pour les transitions mais n'est plus maintenu.
  <https://m3.material.io/styles/motion/easing-and-duration/tokens-specs>
  ~ La spec ajoute que les produits devraient migrer vers le nouveau système.
- Flutter 3.47 publie package:material_ui et cupertino_ui en 1.0.0 (opt-in), copies du code gelé depuis Flutter 3.44. La migration se fait par `dart fix --apply --code=migrate_design_widgets` et l'import `package:material_ui/material_ui.dart`. La dépréciation formelle des bibliothèques intégrées au framework est prévue dans une prochaine version stable.
  <https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui>
  ~ La page ne nomme pas la version stable de la dépréciation. Il faut parfois ajouter les paquets à la main (flutter pub add material_ui).
- google_fonts (9.0.0 sur pub.dev) utilise en priorité les fichiers de police déclarés dans les assets du pubspec plutôt que le fetch HTTP, ce qui convient au hors-ligne. `GoogleFonts.config.allowRuntimeFetching = false` désactive toute requête HTTP. Le fetch runtime met en cache sur le système de fichiers et exige sur macOS l'entitlement com.apple.security.network.client.
  <https://pub.dev/packages/google_fonts>
  ~ Nuance: allowRuntimeFetching is not named on the pub.dev page, which points to the API docs. The API docs confirm GoogleFontsConfig.allowRuntimeFetching (default true): 'Whether or not the GoogleFonts library can make requests to fonts.google.com'.
  ~ Le README renvoie à la doc API pour désactiver le fetch. allowRuntimeFetching est documenté dans l'API de GoogleFonts.config.
- Licences des polices : google_fonts demande d'ajouter la licence de chaque police (par exemple le fichier OFL.txt) au LicenseRegistry de l'app, via LicenseRegistry.addLicense dans main().
  <https://pub.dev/packages/google_fonts>
## CONTESTED (2)
- Breakpoints M3, anciennement « window size classes » et renommés en mai 2026 : compact < 600dp, medium 600–839dp, expanded 840–1199dp, large 1200–1599dp, extra-large ≥ 1600dp. M3 recommande 1 volet en compact/medium, 2 en expanded/large et jusqu'à 3 en extra-large.
  <https://m3.material.io/foundations/layout/breakpoints/overview>
  ~ The page says 'A breakpoint (previously window size class)' but gives no rename date, so 'May 2026' is unsourced. Ranges are correct: compact under 600, medium 600-839, expanded 840-1199, large 1200-1599, extra-large 1600dp+. Panes table: compact 1; medium '1 (recommended) or 2'; expanded and large '1 or 2 (recommended)'; extra-large '1 to 3 (recommended)'. The quoted 'Extra-large breakpoints: Con
  ~ La page dit seulement « A breakpoint (previously window size class) », sans date de renommage : la date « mai 2026 » n'est pas vérifiée, il faut la retirer. Le tableau détaille les volets : compact 1, medium 1 (recommandé) ou 2, expanded et large 1 ou 2 (recommandé), extra-large 1 à 3 (recommandé).
  ! The rename date is not on the page and the citation is absent. The pane split is also simplified: medium allows 2 panes.
- Statut de M3 Expressive dans Flutter au 2026-09-09 : pas encore livré. Le blog officiel indique seulement que des implémentations officielles sont en cours, hors du framework, via material_ui. Les composants Expressive actuels viennent de paquets tiers (m3e_collection, m3_expressive).
  <https://flutter.dev/blog/decoupling-material-cupertino>
  ~ The blog (September 9, 2026) says only 'work is already underway on official implementations of Liquid Glass and Material 3 Expressive', together with community package authors. It does not say this happens via material_ui, and it does not name m3e_collection or m3_expressive.
  ~ Le billet (daté du 2026-09-09) ne dit pas explicitement que la livraison passera par material_ui. Il parle seulement d'implémentations officielles en cours, avec les auteurs de paquets. La citation des paquets tiers vient d'une source secondaire.
  ! The attribution to material_ui and the third-party package names are not in the cited source, so the claim goes beyond it.
## KILLED (0)
## GAPS
- Échelles modulaires (ratio, par exemple 1.25) : aucune source primaire M3 ou Flutter n'a été lue sur ce point. M3 ne définit pas de ratio modulaire ; l'échelle est une table fixe.
- La grille 4dp (« baseline grid » 4dp pour icônes et typo) n'a pas été confirmée sur m3.material.io : la page Spacing lue indique une échelle de 8dp (space100 = 8dp). Les valeurs exactes des tokens d'espacement (space050 ?, space150…) et des marges par breakpoint (16/24dp…) n'ont pas été lues.
- Les tokens d'espacement M3 (page Spacing > Tokens) et les détails des panes (largeurs fixes 360dp, etc.) n'ont pas été extraits.
- Les valeurs des springs M3 Expressive (stiffness/damping, tokens md.sys.motion.spring.*) et leur équivalent Flutter (SpringDescription) n'ont pas été lus.
- L'issue GitHub flutter/flutter #168813 sur M3 Expressive n'a pas été lue directement, seulement le blog officiel du 2026-09-09.
- La page api.flutter.dev de ThemeData n'a pas confirmé explicitement que Typography.material2021 est la typographie par défaut quand useMaterial3 vaut true ; seule la valeur useMaterial3 = true par défaut a été confirmée.
- La page TextTheme indique encore que les styles par défaut correspondent à la spec 2018. Cette affirmation peut être trompeuse sous M3, à vérifier dans le code de ThemeData.
- Une base spécifique aux polices embarquées (déclaration fonts: dans pubspec, polices variables) n'a pas été lue sur docs.flutter.dev (cookbook Use a custom font).

## Passe 2 — widgetbook-generator

## KEPT (20)
- Au 2026-10-27, la dernière version stable de widgetbook sur pub.dev est 3.25.0, publiée le 2026-06-25. Elle exige Dart >=3.10.0 <4.0.0 et Flutter >=3.44.0, et dépend de widgetbook_annotation ^3.11.0. La préversion est 4.0.0-beta.14.
  <https://pub.dev/packages/widgetbook/changelog>
- Les versions stables compatibles avec widgetbook 3.25.0 sont widgetbook_annotation 3.11.0 (2026-02-18, Dart >=3.10.0) et widgetbook_generator 3.24.0 (2026-06-08), qui dépend de widgetbook_annotation ^3.11.0 et d'analyzer >=8.2.0 <14.0.0. La CLI widgetbook_cli stable est en 3.15.0 (métadonnées de l'API pub.dev, https://pub.dev/api/packages/widgetbook_generator).
  <https://pub.dev/packages/widgetbook_annotation/changelog>
  ~ Nuance: widgetbook_cli 3.15.0 requires Dart >=3.11.0 (stricter than the others); widgetbook_generator 3.24.0 requires Dart >=3.10.0.
  ~ Nuance : widgetbook_cli 3.15.0 (2026-06-08) exige Dart >=3.11.0, plus que les autres packages. widgetbook_generator a aussi des préversions 4.0.0-alpha.4.
- widgetbook 3.24.0 a fixé le minimum à Flutter 3.44.0. La 3.22.0 avait fixé Dart 3.10.0 et Flutter 3.38.0. Flutter 3.47 satisfait donc la contrainte de la 3.25.0.
  <https://pub.dev/packages/widgetbook/changelog>
- Correction de l'affirmation 3 : le changelog confirme que la 3.11.0 a fixé Dart >=3.3.0 et Flutter >=3.19.0, et que la 3.14.1 ajoute le support de Flutter 3.32.0. Ces minimums sont obsolètes : la 3.25.0 exige Dart 3.10 et Flutter 3.44.
  <https://pub.dev/packages/widgetbook/changelog>
  ~ Precisely, 3.14.1 is a FIX 'Support Flutter 3.32.0', not a new minimum; the 3.32.0 minimum was set later (with Dart 3.8.0).
  ~ Pour un historique complet, il manque les étapes intermédiaires : 3.16.0 (Dart 3.7/Flutter 3.29), 3.20.0 (3.8/3.32), 3.21.0 (3.9/3.35), 3.22.0 (3.10/3.38).
- Le Quick Start officiel crée une app Flutter séparée `widgetbook` (flutter create widgetbook --empty) et la renomme `widgetbook_workspace` pour éviter le conflit avec le package widgetbook. On ajoute ensuite les dépendances avec `flutter pub add widgetbook widgetbook_annotation dev:widgetbook_generator dev:build_runner`, et l'app à cataloguer en dépendance path.
  <https://docs.widgetbook.io/quick-start>
  ~ The rename is done in widgetbook/pubspec.yaml; the doc also shows a variant with --platforms=web,macos.
- La doc recommande d'importer widgetbook_annotation avec l'alias `widgetbook` (import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;). On écrit alors @widgetbook.App() et @widgetbook.UseCase(...).
  <https://docs.widgetbook.io/use-cases/annotations>
- L'annotation @App fixe l'emplacement du fichier généré. Une classe annotée dans lib/main.dart produit lib/main.directories.g.dart, qui expose la variable `directories` à passer à Widgetbook.material(directories: directories). La génération se lance avec `dart run build_runner build -d`.
  <https://docs.widgetbook.io/use-cases/annotations>
  ~ The variable `directories`, Widgetbook.material(directories: directories) and 'dart run build_runner build -d' come from the Quick Start page, not from the annotations page cited.
  ~ Nuance de source : la commande `dart run build_runner build -d` et Widgetbook.material(directories: directories) figurent dans le Quick Start, pas sur la page annotations.
- Dans widgetbook_annotation 3.11.0, le constructeur UseCase accepte name (requis), type (requis), designLink, path, cloudKnobsConfigs (type KnobsConfigs?), exclude (false par défaut) et cloudExclude (false par défaut). Les configs d'addons multi-snapshot vont sur @App, via le paramètre cloudAddonsConfigs (AddonsConfigs?).
  <https://raw.githubusercontent.com/widgetbook/widgetbook/main/packages/widgetbook_annotation/lib/src/use_case.dart>
- Correction de l'affirmation 4 : sur @UseCase, le paramètre de knobs multi-snapshot s'appelle exactement `cloudKnobsConfigs`. La page Multi Snapshot Reviews contient une coquille : son exemple de knobs utilise `cloudAddonsConfigs` sur @UseCase, alors que ce nom n'existe que sur @App.
  <https://docs.widgetbook.io/cloud/snapshots/multi-snapshot>
- Le paramètre `type` de @UseCase sert au générateur à créer l'entrée de composant dans la navigation. Il faut y mettre le type du composant catalogué (par ex. CoolButton), pas celui que renvoie le builder (par ex. Center).
  <https://docs.widgetbook.io/use-cases/annotations>
- Par défaut, le chemin de navigation suit l'emplacement du fichier du composant. L'option build.yaml `nav_path_mode: use-case` du builder `widgetbook_generator:use_case_builder` le base plutôt sur le fichier du use case. Le paramètre `path` le surcharge localement, et un segment entre crochets devient une catégorie (`[Interactions]/buttons`).
  <https://docs.widgetbook.io/configure/use-case-nav-path>
- Pour un monorepo, la doc décrit deux approches. La première est un seul Widgetbook à la racine (monorepo/widgetbook/) qui dépend en path de packages/my_design_system et de my_app. La seconde est un Widgetbook par package (packages/my_design_system/widgetbook/). Avec Melos, il peut falloir passer par des dépendances versionnées et ajouter widgetbook/ aux packages de melos.yaml.
  <https://docs.widgetbook.io/essentials/monorepo>
  ~ In the doc's per-package tree, my_app also has its own widgetbook/ folder (my_app/widgetbook/).
- La commande CLI `widgetbook coverage` est expérimentale. Elle mesure le pourcentage de widgets d'un package couverts par au moins un use case. Ses arguments sont --package (défaut ./), --widgetbook (défaut ./widgetbook) et --min-coverage (défaut 100). Un widget est exclu avec le commentaire `// widgetbook: ignore`.
  <https://docs.widgetbook.io/cli/commands/coverage>
- ViewportAddon n'est plus expérimental depuis widgetbook 3.15.0, qui a retiré son annotation @experimental et déprécié DeviceFrameAddon. Dans les sources de la 3.25.0, SemanticsAddon (comme TimeDilationAddon) porte encore @experimental, et DeviceFrameAddon est @Deprecated.
  <https://pub.dev/packages/widgetbook/changelog>
- La doc de SemanticsAddon le présente comme expérimental, avec des ruptures possibles à chaque version mineure. Il doit être placé après tous les autres addons, parce que ceux-ci peuvent ajouter des nœuds de sémantique.
  <https://docs.widgetbook.io/addons/semantics-addon>
- L'ordre des addons compte : le premier de la liste est le widget le plus externe. ViewportAddon doit venir avant tous les autres addons, sinon AlignmentAddon aligne le viewport au lieu du use case.
  <https://docs.widgetbook.io/addons/overview>
- ViewportAddon et DeviceFrameAddon doivent précéder ThemeAddon (et ses variantes MaterialThemeAddon et CupertinoThemeAddon). Historiquement, la 3.1.0 a remplacé le Scaffold autour des use cases par un ColoredBox sous le Theme, et ThemeAddon a dû passer après DeviceFrameAddon.
  <https://pub.dev/packages/widgetbook/changelog>
  ~ No current doc page names ThemeAddon in its ordering guidance. ViewportAddon-before-ThemeAddon is inferred from 'ViewportAddon before all other addons'; DeviceFrameAddon-before-ThemeAddon comes from the 3.1.0 changelog.
  ~ Nuance : aucune page de doc actuelle ne mentionne explicitement ThemeAddon. Pour ViewportAddon, on le déduit de la règle « before all other addons ». Pour DeviceFrameAddon (déprécié), la règle vient du CHANGELOG 3.1.0.
- ViewportAddonConfig, utilisé dans cloudAddonsConfigs pour le multi-snapshot, est défini dans le package widgetbook et non dans widgetbook_annotation. Le fichier qui porte @App doit donc importer les deux packages.
  <https://docs.widgetbook.io/addons/viewport-addon>
- Approche générée contre approche manuelle : depuis la 3.0, la génération de code ne porte plus que sur @App et @UseCase, qui produisent la liste `directories`. Les addons, l'appBuilder et les autres propriétés de Widgetbook se configurent toujours à la main dans le constructeur.
  <https://pub.dev/packages/widgetbook_annotation/changelog>
  ~ This is the widgetbook_annotation 3.0.0 changelog entry (PR #663).
- Correction de l'affirmation 5 : Widgetbook Cloud crée automatiquement une review par PR et en publie l'URL dans un commit status, sans aucun test golden. Le merge n'est bloqué que si des changements sont demandés (« request changes »), pas pour une review simplement non approuvée. Ce blocage se désactive dans les réglages du projet.
  <https://docs.widgetbook.io/cloud/reviews>
  ~ Nuance: 'without writing any golden tests' refers to detecting regressions with zero configuration. The page does not state 'one review per PR' explicitly, only that Cloud creates a review for your PR. Widgetbook Cloud integration is still required.
  ~ Nuance : la doc dit seulement qu'une demande de changements bloque le merge. Elle ne dit pas explicitement qu'une review non approuvée ne le bloque pas : c'est une interprétation par omission.
## CONTESTED (0)
## KILLED (0)
## GAPS
- La page monorepo de docs.widgetbook.io ne parle que de dépendances path et de Melos. Elle ne dit rien des pub workspaces Dart (resolution: workspace) : rien de vérifié sur ce point.
- Je n'ai pas lu la page pub.dev ni le changelog de widgetbook_generator 3.24.0 (pour d'éventuels pièges propres au générateur). Ses versions et contraintes viennent de l'API JSON pub.dev.
- La 4.0.0-beta.14 n'a pas été analysée : le guide v4 (docs.widgetbook.io/~v4) n'a pas été lu, donc rien sur ses ruptures d'API.
- Sur la doc multi-snapshot, l'incohérence cloudKnobsConfigs/cloudAddonsConfigs a été tranchée par le code source de widgetbook_annotation (branche main sur GitHub et archive pub.dev 3.11.0), pas par une erratum officielle.

## Passe 2 — widgetbook-testing

## KEPT (22)
- alchemist est en version 0.14.1 sur pub.dev, publiée environ 19 jours avant le 2026-10-27. Le seul changement noté est la prise en charge d'equatable 3.x. La version 0.14.0 ajoutait diffThreshold et corrigeait la lenteur du chargement des polices.
  <https://pub.dev/packages/alchemist/changelog>
- alchemist 0.13.0 désactive l'anti-aliasing sur BlockedTextPaintingContext. Les goldens CI existants peuvent donc changer après une montée de version et doivent alors être régénérés une fois. Depuis la 0.12.0, la version minimale de Flutter est 3.32.0.
  <https://pub.dev/packages/alchemist/changelog>
  ~ Nuance: 0.13.0 also fixes a cross-platform anti-aliasing problem (#165). The anti-aliasing change is flagged as breaking.
  ~ 0.13.0 also contains the fix 'Anti-aliasing cross-platform issue' (#165).
- Dans alchemist, diffThreshold fixe le ratio maximal de pixels différents toléré, entre 0.0 inclus et 1.0 exclu (0.001 = 0,1 %). La valeur par défaut est 0.0, soit aucune tolérance.
  <https://pub.dev/documentation/alchemist/latest/>
- alchemist produit deux types de goldens. Les goldens CI utilisent toujours la police Ahem, masquent le texte par des rectangles (obscureText true par défaut) et vont dans goldens/ci/. Les goldens plateforme gardent un texte lisible et vont dans goldens/<platform_name>/.
  <https://pub.dev/packages/alchemist>
  ~ Nuance: the README fetch did not show the 'true by default' value for obscureText. It only defines obscureText ('obscured by colored rectangles'). The CI default of true is consistent with the CiGoldensConfig API but was not quoted.
  ~ obscureText defaults to true for CI goldens and false for platform goldens. The goldens/ci/ and goldens/<platform_name> paths are relative to the test file.
- Tous les tests golden alchemist reçoivent par défaut le tag "golden". On peut donc les isoler avec `flutter test --tags golden` ou les exclure avec `flutter test --exclude-tags golden`.
  <https://pub.dev/packages/alchemist>
- Pour appliquer un AlchemistConfig commun à tout un package (par exemple PlatformGoldensConfig(enabled: false) en CI), on crée test/flutter_test_config.dart et on y enveloppe testMain dans AlchemistConfig.runWithConfig.
  <https://pub.dev/documentation/alchemist/latest/>
- golden_toolkit est marqué « discontinued » sur pub.dev. Sa dernière version est la 0.15.0, publiée il y a environ 3 ans, et aucun remplaçant n'est indiqué. Il ne faut pas l'adopter dans un nouveau design system.
  <https://pub.dev/packages/golden_toolkit>
  ~ The 'do not adopt' part is an internal recommendation, not something the page states.
  ~ The advice not to adopt it is a recommendation, not a statement from pub.dev.
- La signature de matchesGoldenFile dans flutter_test est `AsyncMatcher matchesGoldenFile(Object key, {int? version})`. Les fichiers de référence se créent ou se mettent à jour avec `flutter test --update-goldens`, et la comparaison passe par goldenFileComparator.
  <https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html>
- Selon la doc de matchesGoldenFile, une police personnalisée peut être rendue différemment selon la plateforme et selon la version de Flutter. Par défaut, le framework utilise Ahem, qui dessine des carrés à la place des caractères.
  <https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html>
- (Affirmation 1 revérifiée et corrigée.) Une source secondaire (Theodo) constate que les goldens diffèrent entre Linux et macOS à cause du lissage des polices. Elle recommande d'exécuter les tests locaux et CI dans le même environnement Docker. En revanche, aucune source lue ne dit de régénérer « seulement le dossier concerné ». Côté Flutter, la règle est de mettre à jour la baseline quand le rendu change, puis de vérifier les images.
  <https://www.theodo.com/blog/reduce-your-ci-cost-using-docker-to-run-local-tests>
  ~ This is a secondary source (blog), so it is not primary.
- Le matcher meetsGuideline(AccessibilityGuideline) est asynchrone. Il faut donc l'attendre (await expectLater) et activer la sémantique avant, via tester.ensureSemantics(), puis libérer le handle par handle.dispose().
  <https://api.flutter.dev/flutter/flutter_test/meetsGuideline.html>
- androidTapTargetGuideline impose aux nœuds sémantiques tapables une taille minimale de 48 x 48.
  <https://api.flutter.dev/flutter/flutter_test/androidTapTargetGuideline-constant.html>
- iOSTapTargetGuideline impose aux nœuds sémantiques tapables une taille minimale de 44 x 44.
  <https://api.flutter.dev/flutter/flutter_test/iOSTapTargetGuideline-constant.html>
- labeledTapTargetGuideline exige un label sur tout nœud ayant une action tap ou long press. textContrastGuideline vérifie le contraste du texte selon le WCAG, sans que la page API n'en donne les seuils.
  <https://api.flutter.dev/flutter/flutter_test/labeledTapTargetGuideline-constant.html>
- accessibility_tools est en version 3.0.0, publiée par rebelappstudio.com (éditeur vérifié). Il s'installe dans le builder de MaterialApp, ne tourne qu'en debug et est retiré des builds release. Ses vérificateurs de zone tactile prennent par défaut 48x48 sur mobile et 44x44 sur desktop.
  <https://pub.dev/packages/accessibility_tools>
  ~ Version 3.0.0 was published about 46 days ago.
- Le vérificateur de débordement de texte agrandi d'accessibility_tools est expérimental et désactivé par défaut. On l'active avec checkFontOverflows: true. IgnoreMinimumTapAreaSize sert à neutraliser l'alerte de zone tactile dans les cas d'exception.
  <https://pub.dev/packages/accessibility_tools>
- Dans Widgetbook, AccessibilityAddon est déprécié. La doc recommande d'envelopper les use cases avec BuilderAddon(name: 'Accessibility', builder: (context, child) => AccessibilityTools(child: child)).
  <https://docs.widgetbook.io/addons/accessibility-addon>
  ~ Nuance: the accessibility-addon page only says 'Please use the BuilderAddon + accessibility_tools instead' and links to it. The BuilderAddon(name: 'Accessibility', builder: ... AccessibilityTools(child: child)) code is on docs.widgetbook.io/addons/builder-addon#accessibility_tools.
  ~ The addon page recommends 'BuilderAddon + accessibility_tools' and links to the builder-addon page. The exact code was not checked on the page I fetched, but it is consistent with that recommendation.
- Widgetbook Cloud crée automatiquement une review visuelle par PR, qui compare les builds base et head sans écrire de tests golden. Une demande de changements bloque le merge par défaut, ce qu'on peut désactiver dans les réglages du projet.
  <https://docs.widgetbook.io/cloud/reviews>
- Le snapshot est l'unité de facturation de Widgetbook Cloud, avec Snapshots = configs de knobs x configs d'addons par use case. Un use case s'exclut avec `cloudExclude: true` dans l'annotation @UseCase.
  <https://docs.widgetbook.io/cloud/snapshots/overview>
  ~ A use case with no knob configs counts as 1.
- La comparaison visuelle de Widgetbook Cloud gère mal les animations (par exemple CircularProgressIndicator) et les valeurs aléatoires. La doc conseille de désactiver les animations en contexte Cloud ou via un knob booléen, et de remplacer l'aléatoire par des constantes.
  <https://docs.widgetbook.io/cloud/reviews/limitations>
  ~ Nuance: the doc also suggests a knob with a default value as an alternative to constants for random values.
  ~ For random values, the doc also offers a knob with a default value.
- La commande expérimentale `widgetbook coverage` mesure le pourcentage de widgets du package couverts par au moins un use case. Ses options sont --package, --widgetbook et --min-coverage (100 par défaut), et `// widgetbook: ignore` exclut un widget du calcul.
  <https://docs.widgetbook.io/cli/commands/coverage>
  ~ Nuance: the defaults for --package (./) and --widgetbook (./widgetbook) are also documented, and the command can change in any minor version.
  ~ Default values are --package ./ and --widgetbook ./widgetbook. The doc warns that breaking changes can come in any minor version.
- Pour rejouer les use cases Widgetbook 3.x en goldens flutter_test, il existe le paquet communautaire widgetbook_golden_test 0.5.1 (uploader non vérifié, dépend de widgetbook ^3.20.2). On appelle runWidgetbookGoldenTests(nodes: directories, ...) sur main.directories.g.dart. Le paquet officiel widgetbook_test n'est qu'un placeholder.
  <https://pub.dev/packages/widgetbook_golden_test>
  ~ Nuance: widgetbook_test (verified publisher widgetbook.io) is at 3.0.0 with a 4.0.0-alpha.3 prerelease. Its page says it 'currently do nothing' and is a placeholder; that is checked on its own page, not the cited one. runWidgetbookGoldenTests also takes properties: WidgetbookGoldenTestsProperties().
  ~ widgetbook_golden_test 0.5.1 was published about 5 months ago and also depends on widgetbook_golden_test_core ^0.5.0. widgetbook_test is 3.0.0 (with 4.0.0-alpha.3 in prerelease) and is still a placeholder.
## CONTESTED (0)
## KILLED (0)
## GAPS
- Docs Widgetbook v4 sur les tests (scenarios et goldens) : https://docs.widgetbook.io/~v4/testing renvoie une 404, la page n'a pas été lue.
- Seuils WCAG appliqués par textContrastGuideline (4.5:1 ou 3:1) : la page API ne les donne pas.
- La doc Widgetbook ne dit rien de l'environnement de rendu des snapshots Cloud (OS, polices).
- accessibility_tools ne documente aucun usage en tests automatisés ou en CI.
- Affirmation précédente 1 : 'régénérer seulement pour le dossier concerné' n'est confirmé par aucune source lue. Seule la partie Docker est étayée, par une source secondaire.
- Le texte précis du guide officiel des goldens dans docs.flutter.dev n'a pas été trouvé ni lu.
- Je n'ai pas vérifié si widgetbook_golden_test est compatible avec Widgetbook 3.25.0.
