import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:a2ui_flutter/a2ui_flutter.dart'
    show CatalogImplementation, ComponentImplementation;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Lit les lignes de la fixture `<variant>-<name>.jsonl` du contrat
/// (`act1` par défaut), en substituant `${CATALOG_ID}` textuellement.
List<Map<String, dynamic>> contractFixture(
  String name,
  String catalogId, {
  String variant = 'act1',
}) {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/contracts/a2ui/genesis/v1').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('contracts/ introuvable');
    dir = parent;
  }
  return File(
        '${dir.path}/contracts/a2ui/genesis/v1/examples/$variant-$name.jsonl',
      )
      .readAsLinesSync()
      .where((String l) => l.trim().isNotEmpty)
      .map(
        (String l) =>
            jsonDecode(l.replaceAll(r'${CATALOG_ID}', catalogId))
                as Map<String, dynamic>,
      )
      .toList();
}

/// Moteur + Bloc + plateau pour tester un composant du catalogue sur sa
/// fixture. Les erreurs du moteur (`model.onError`) sont collectées.
class CatalogHarness {
  CatalogHarness(
    this.surface,
    this.fixtureName, {
    this.size = const Size(940, 255),
    this.fontFamily,
    this.fontFamilyFallback,
    this.variant = 'act1',
  }) {
    controller = a2ui.MessageProcessor<ComponentImplementation>(
      catalogs: <CatalogImplementation>[genesisCatalog()],
      validationConfig: a2ui.ValidationConfig.relaxed,
    );
    bloc = CanvasBloc(controller);
    _sub = controller.model.onError.subscribe(
      (a2ui.A2uiRendererError e) => engineErrors.add(jsonEncode(e.toJson())),
    );
    fixture = contractFixture(
      fixtureName,
      GenesisContract.defaultCatalogId,
      variant: variant,
    );
    addTearDown(() async {
      _sub.unsubscribe();
      await bloc.close();
      controller.dispose();
    });
  }

  final String surface;
  final String fixtureName;
  final Size size;

  /// Préfixe de la fixture du contrat (`act1`, ou `crashlist` pour
  /// `crashlist-global.jsonl`).
  final String variant;

  /// Famille (et familles de repli) du thème Material : par défaut la police
  /// de test (Ahem) ; un test de budget de hauteur y met des polices réelles.
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  late final a2ui.MessageProcessor<ComponentImplementation> controller;
  late final CanvasBloc bloc;
  late final a2ui.Subscription _sub;
  late final List<Map<String, dynamic>> fixture;
  final List<String> engineErrors = <String>[];

  /// Objet du data model de la fixture (3e message).
  Map<String, dynamic> get data =>
      ((fixture[2]['updateDataModel'] as Map<String, dynamic>)['value']
          as Map<String, dynamic>);

  /// Monte le canevas. Sans [motion], aucun `SceneMotionScope` n'est posé :
  /// animations actives, vitesse 1 (réglage par défaut). Avec [motion],
  /// `disabled` coupe les durées et `speed` est la vitesse de rejeu.
  Future<void> pump(
    WidgetTester tester, {
    ({bool disabled, double speed})? motion,
  }) => tester.pumpWidget(
    _withMotion(
      motion,
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
        ),
        home: Scaffold(
          body: BlocProvider<CanvasBloc>.value(
            value: bloc,
            child: SizedBox(
              width: size.width,
              // La cellule garde `size` : le bandeau réservé s'ajoute (A1).
              height: size.height + CanvasBoard.actionsBandHeight,
              child: CanvasBoard(controller: controller),
            ),
          ),
        ),
      ),
    ),
  );

  static Widget _withMotion(
    ({bool disabled, double speed})? motion,
    Widget child,
  ) => motion == null
      ? child
      : SceneMotionScope(
          disabled: motion.disabled,
          speed: motion.speed,
          child: child,
        );

  Future<void> send(WidgetTester tester, Map<String, dynamic> json) async {
    bloc.add(A2uiMessageReceived(a2ui.AgentToRendererMessage.fromJson(json)));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  /// Objet du data model de la variante [variant] (copie modifiable).
  Map<String, dynamic> variantData(String variant) => cloneJson(
    (contractFixture(
              fixtureName,
              GenesisContract.defaultCatalogId,
              variant: variant,
            ).single['updateDataModel']
            as Map<String, dynamic>)['value']
        as Map<String, dynamic>,
  );

  /// Envoie la mise à jour de données de la variante [variant] (`act2`,
  /// `correction-ios`) de la fixture de cette surface.
  Future<void> sendVariant(WidgetTester tester, String variant) async {
    for (final Map<String, dynamic> message in contractFixture(
      fixtureName,
      GenesisContract.defaultCatalogId,
      variant: variant,
    )) {
      await send(tester, message);
    }
  }

  Future<void> sendFixtureTo(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await send(tester, fixture[i]);
    }
  }

  /// Remplace l'objet du data model par [value].
  Future<void> sendData(WidgetTester tester, Object? value) =>
      send(tester, <String, dynamic>{
        'version': 'v0.9',
        'updateDataModel': <String, dynamic>{
          'surfaceId': surface,
          'path': '/$surface',
          'value': value,
        },
      });

  Finder inCell(Finder finder) => find.descendant(
    of: find.byKey(Key('surface-$surface')),
    matching: finder,
  );

  /// Vérifie que tous les textes de la cellule font au moins 11 px (le plus petit style de l'échelle du design system, pdr-0087).
  void expectTextAtLeastScaleMinimum(WidgetTester tester) {
    final paragraphs = tester
        .renderObjectList<RenderParagraph>(inCell(find.byType(RichText)))
        .toList();
    expect(paragraphs, isNotEmpty);
    for (final RenderParagraph p in paragraphs) {
      // pdr-0087 / pdr-0088 F1 : échelle du design system (11 px au plus bas), plus de plancher de 24 px.
      expect(
        p.text.style?.fontSize,
        greaterThanOrEqualTo(11),
        reason: '${p.text}',
      );
    }
  }
}

/// Copie profonde modifiable d'un objet JSON.
Map<String, dynamic> cloneJson(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

/// Tests communs aux trois composants : squelette, sans données, neutre.
void defineCommonStateTests({
  required String component,
  required String surface,
  required String fixtureName,
  required String completeText,
  Map<String, Object?> badValues = const <String, Object?>{},
  String variant = 'act1',
}) {
  testWidgets('$component : squelette puis sans données puis complet', (
    tester,
  ) async {
    final h = CatalogHarness(surface, fixtureName, variant: variant);
    await h.pump(tester);

    await h.sendFixtureTo(tester, 1);
    expect(find.byKey(Key('skeleton-$surface')), findsOneWidget);
    expect(find.textContaining(completeText), findsNothing);

    await h.send(tester, h.fixture[1]);
    expect(find.byKey(Key('nodata-$surface')), findsOneWidget);
    expect(find.byKey(Key('skeleton-$surface')), findsNothing);
    expect(find.byKey(Key('neutral-$surface')), findsNothing);
    expect(find.textContaining(completeText), findsNothing);

    await h.send(tester, h.fixture[2]);
    expect(find.byKey(Key('nodata-$surface')), findsNothing);
    expect(find.byKey(Key('neutral-$surface')), findsNothing);
    expect(h.inCell(find.textContaining(completeText)), findsWidgets);
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final String field in GenesisContract.requiredFields[component]!) {
    testWidgets('$component sans le champ requis $field : état neutre', (
      tester,
    ) async {
      final h = CatalogHarness(surface, fixtureName, variant: variant);
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendData(tester, cloneJson(h.data)..remove(field));

      expect(find.byKey(Key('neutral-$surface')), findsOneWidget);
      expect(find.text('Données indisponibles'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
    });
  }

  for (final MapEntry<String, Object?> bad in <String, Object?>{
    'objet de mauvais type': 'texte',
    'objet vide': <String, Object>{},
    ...badValues,
  }.entries) {
    testWidgets('$component, ${bad.key} : état neutre sans exception', (
      tester,
    ) async {
      final h = CatalogHarness(surface, fixtureName, variant: variant);
      await h.pump(tester);
      await h.sendFixtureTo(tester, 2);
      await h.sendData(tester, bad.value);

      expect(find.byKey(Key('neutral-$surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(h.engineErrors, isEmpty);
    });
  }

  testWidgets('$component : textes >= 11 px, sans débordement à 940 x 255', (
    tester,
  ) async {
    final h = CatalogHarness(surface, fixtureName, variant: variant);
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    h.expectTextAtLeastScaleMinimum(tester);
    expect(tester.takeException(), isNull);
    expect(h.engineErrors, isEmpty);
  });

  testWidgets('$component : l état neutre ne déborde pas non plus', (
    tester,
  ) async {
    final h = CatalogHarness(surface, fixtureName, variant: variant);
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendData(tester, cloneJson(h.data)..remove('title'));
    expect(tester.takeException(), isNull);
  });
}

/// Hauteur d'une ligne du style `title` (18 px sur 24 px d'interligne dans le
/// design system) : un titre qui a passé à la ligne dépasse 1,5 fois cette
/// hauteur. Remplace les 31,2 px du plancher de 24 px (pdr-0087 / pdr-0088 F1).
double titleLineHeight() {
  const SceneTheme theme = SceneTheme.dark();
  return theme.title.fontSize! * theme.title.height!;
}

/// Hauteur d'une ligne du style `body` (15 px sur 22 px d'interligne).
double bodyLineHeight() {
  const SceneTheme theme = SceneTheme.dark();
  return theme.body.fontSize! * theme.body.height!;
}
