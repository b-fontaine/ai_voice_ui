---
id: p-ar-design-system-motion
title: Mouvement du design system du 2026-11-02 (019) : jetons, primitives, boucles, mouvement réduit
area: architecture
status: draft
updated: 2026-11-03
sources: [specs/019-design-system-fidelity/spec.md, specs/019-design-system-fidelity/plan.md, specs/019-design-system-fidelity/status.md, product/sources/design-system-2026-11-02/README.md, product/sources/design-system-2026-11-02/components/bundle.css, packages/shared/design_system/lib/src/scene_motion.dart, packages/shared/design_system/lib/src/scene_one_shot.dart, packages/shared/design_system/lib/src/scene_loop.dart, packages/shared/design_system/lib/src/ds_rise.dart, packages/shared/design_system/lib/src/ds_gen_frame.dart, knowledge:ds-motion, knowledge:perf-repaint-boundary]
links: [p-ar-design-system-look, p-ar-design-system, p-ar-frontend-screen, p-ar-quality, p-fn-nfr, p-fn-feature-design-system-019-mouvement, pdr-0087-design-system-fidelity-no-24px-minimum, pdr-0088-019-design-system-fidelity-ui-details-assistant-decided, pdr-0084-017-design-system-ui-details-assistant-decided, p-rm-backlog, p-rm-open-questions, ds-motion, perf-repaint-boundary]
tags: [design-system, animation, mouvement, nfr-04, repaint-boundary, 019]
---
# Mouvement du design system du 2026-11-02 (019)

**En bref.** 019 reprend les animations du design system (README § Mouvement, `bundle.css` ; [pdr-0087](../decisions/pdr-0087-design-system-fidelity-no-24px-minimum.md) D3, [pdr-0088](../decisions/pdr-0088-019-design-system-fidelity-ui-details-assistant-decided.md) F5, F9, F13) : 17 animations, 12 de niveau A et 5 de niveau B (coupables en dernier). Une seule source de réglage (`SceneMotionScope`), des durées en jetons `scene.motion.*`, un `RepaintBoundary` par boucle. Structure des composants : [p-ar-design-system-look](design-system-look.md) ; socle et jetons : [p-ar-design-system](design-system.md) ; scénarios A-01 à A-07 : [p-fn-feature-design-system-019-mouvement](../functional/features/design-system-019-mouvement.feature).

## Jetons et portée

- **Jetons `scene.motion.*`** (34, façade `SceneMotion`, parité testée dans les deux sens) : durées `value` 160 ms, `appear` et `row` 480 ms, `count` et `gauge` 1,4 s, courbe `Cubic(.2, .8, .2, 1)`, translation 10 px, flou σ 4 (`blur`), échelle .985 (`scale`), puis une durée par animation (`wipe` 1600, `stagger` 180, `spin` 2800, `scan` 2200, `fade` 600, `flash` 1200, `wave` 1000, `orbRing` 2400, `indet` 1300, `ring` 1800, `blink` 1000, et depuis la revue du code `caretBlink` 900, `caretHold` 1200, `recBlink` 1200, `agentBeacon` 1200, `headDelay` 1500, `headRise` 400, `streamRow` 350, `splitDelay` 200). Chaque durée est **divisée par la vitesse de rejeu**, avec un plancher de 60 ms.
- **`SceneMotionScope`** enveloppe **toute la scène**, pied (catalogue, rejeu) et panneau du protocole compris : avant 019, ces deux zones étaient hors scope et le repli rendait les animations actives sans le dire. Sous `disableAnimations`, en mode scénario ou en capture, durée nulle et boucles immobiles : `SceneMotionScope` est l'unique source de ce réglage.
- **Mesure** : un test de page aux actes 1 à 3, en scénario puis sous `disableAnimations`, exige `tester.binding.transientCallbackCount == 0` (`page_motion_scope_test`, A-07). Les captures `app-smoke` tournent sans animation : le mouvement se prouve par des tests à horloge simulée, jamais par capture.

## Primitives (`packages/shared/design_system`)

| Primitive | Rôle |
|---|---|
| `SceneOneShot` (mixin de `State`) | animation ponctuelle (compteur, jauge, barre de répartition, cascade, tracé, lueur de puce) : un contrôleur, `playOneShot`, état final immédiat si coupée, `completeIfDisabled` dans `didChangeDependencies`. **Jamais de `TweenAnimationBuilder`** (il ne s'achève pas si on coupe en cours de lecture) |
| `SceneLoop` (mixin, revue R4) | cycle de vie d'une boucle (`loopBase`, `loopRestValue`, `loopActive`, `loopReverse`, `syncLoop`) : ne relance jamais un `repeat` à période et sens identiques ; remplace huit copies. Gardées à part : `DsGenFrame` et la pulsation de l'orbe |
| `DsRise` | `gc-rise` : arbre **constant** `Opacity` > `Transform` (10 px, échelle .985, centrée en haut) > `ImageFiltered(enabled: t < 1)`, la surface en `child` : son `State` n'est jamais recréé (D-07) ; le flou n'existe que pendant les 480 ms. Les cartes d'avis apparaissent **sans flou** (pas de flou imbriqué). Une surface restaurée (rejeu positionné) s'affiche sans transition (`SurfaceRestored`, `settled`) |
| `DsShift`, `DsReveal` (R5) | translation à la peinture (`hitTestChildren` décalé) et fondu + translation, pour la cascade de la checklist, les cartes d'avis, la tête du graphique et le flux A2UI |
| `DsBlink`, `DsBeacon` | clignotement par créneaux (`steps(2)`, un `FadeTransition`) ; point battant peint (`BeaconPainter`) |
| `DsGenFrame` | cadre de génération : `CustomPainter` (arc `SweepGradient` + balayage), un contrôleur de période 30,8 s (PPCM de 2,8 s et 2,2 s), fin = dernier tour puis fondu de 0,6 s ; second contrôleur pour le losange de l'étiquette |

## Animations livrées

| Niveau | Animations (composant) |
|---|---|
| A | `gc-rise` (surfaces) ; `gc-row` (lignes de la checklist, décalage de 180 ms plafonné à 8) ; `gc-wipe` (tracé du graphique, `ClipRect` à `reclip` au-dessus d'un `RepaintBoundary` qui ne contient que les séries) ; compteur de 100 % vers la valeur (1,4 s, texte final = la chaîne de données) ; largeur de la jauge ; barre de répartition (négatif retardé de 200 ms) ; `gc-spin` et `gc-scan` (cadre de génération) ; `gc-beacon` (Bloquant seul) ; `gc-wave` (onde, 12 barres) et `gc-orbring` (3 anneaux, 2,4 s) quand l'IA parle ; `gc-flash` (puce de catalogue nouvellement utilisée) |
| B | `gc-indet` (barre d'un agent au travail) ; `gc-blink` (curseur de transcription, point d'enregistrement, point « Direct », losange du cadre) ; `gc-ring` (anneau du point de tête, après le tracé) ; `gc-breathe` (noyau de l'orbe, hérité de 017) ; entrée du flux A2UI (350 ms, fondu et −12 px, une seule fois) |

**Déclenchement (F13)** : les animations ponctuelles jouent au premier `data` de la surface, puis à chaque changement de valeur (mutation de l'acte 2) ; une surface restaurée affiche l'état final. Les boucles démarrent et s'arrêtent avec leur état.

## Règles de performance (NFR-04)

- **Un `RepaintBoundary` par boucle**, y compris les animations ponctuelles qui repeignent (une lueur de puce repeignait la couche de la barre vocale : constaté en T33).
- **Phase de repos sous `disabled`** pour chaque boucle : anneaux invisibles, onde au repos, point plein, losange plein. Exception amendée (F13) : la barre indéterminée d'un agent au travail reste **visible et immobile**, elle signale l'état.
- **Onde et anneaux** ont leurs propres contrôleurs (périodes 2,4 s et 1 s, contre 2,0 s pour l'orbe : des phases dérivées auraient sauté à chaque tour), derrière une `SpeakingGate` à hystérésis (sortie sous 0,5 × le seuil) ; écart au plan P2 justifié, consigné dans `plan.md`.
- **Leçon : sous un `LayoutBuilder`, un `AnimatedBuilder` (ou `SlideTransition`) remet en page à chaque image** et repeint le parent (constaté par `debugPrintMarkNeedsLayoutStacks`) : utiliser des transitions de rendu (`FadeTransition`, `CustomPainter(repaint:)`, `DsShift`). Exception de T34, levée par la revue (R3) : le point de la puce de statut gardait un `AnimatedBuilder` parce que U-05 le reconnaissait à un `AnimatedWidget` ; il passe par `DsBeacon` et U-05 compte désormais les notifications des `Listenable`.
- **Garde** : `no_hardcoded_style_test` refuse toute durée littérale (`Duration(milliseconds|seconds: <chiffre>)`) sous `widgets`, `catalog` et le design system hors `*.g.dart` ; voir [p-ar-design-system-look](design-system-look.md).

## Limites et points à observer

- **60 i/s non mesurés** : seule la structure est testée (NFR-04 côté périmètre) ; le flou de `gc-rise` et les boucles se mesurent au profil `--profile` en répétition (J7). Repli prévu : réduire σ ou retirer le flou, ou couper le niveau B (pdr-0088 F5, F9, nouvelle PDR).
- **Saut de phase de `DsGenFrame` à `done`** (`forward(from: 0)`) : effet visuel consigné, non traité par la revue du code (le refactorer ne change pas le comportement). Non vérifié en répétition : rejeu temporisé avec positionnement.
- **Phases de repos de `DsBlink` et `DsBeacon`** : la preuve de leur rouge (retirer la phase de repos et constater l'échec) reste à consigner (revue du code) ; l'invariant « seul Bloquant bat » est vérifié par mutation, mais A-06 ne verrait pas une puce `ok` ou `risk` qui bat (son écran ne montre que des Bloquant) : le test unitaire la couvre.
