import 'dart:async';

import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

/// Faux client (frontière réseau) : rend les résultats scriptés dans l'ordre,
/// puis `accepted`. Un `gate` retient la réponse jusqu'à sa libération.
class _FakeActionClient implements CanvasActionClient {
  _FakeActionClient([List<CanvasActionResult> script = const []])
    : _script = List<CanvasActionResult>.of(script);

  final List<CanvasActionResult> _script;
  final List<({String action, String surface})> calls = [];
  Completer<void>? gate;

  @override
  Future<CanvasActionResult> send({
    required String action,
    required String surface,
  }) async {
    calls.add((action: action, surface: surface));
    final hold = gate;
    if (hold != null) await hold.future;
    return _script.isEmpty ? CanvasActionResult.accepted : _script.removeAt(0);
  }
}

const _fast = CanvasActionSettings(
  retries: 3,
  retryInterval: Duration(milliseconds: 5),
  maxDuration: Duration(seconds: 5),
);

Future<void> _tick([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late List<CanvasActionState> emitted;
  late CanvasActionBloc bloc;
  late StreamSubscription<CanvasActionState> sub;

  CanvasActionBloc build(
    _FakeActionClient client, [
    CanvasActionSettings settings = _fast,
  ]) {
    bloc = CanvasActionBloc(client: client, settings: settings);
    emitted = <CanvasActionState>[];
    sub = bloc.stream.listen(emitted.add);
    return bloc;
  }

  tearDown(() async {
    await sub.cancel();
    await bloc.close();
  });

  void click([String name = 'block_release']) =>
      bloc.add(ActionRequested(name, 'actions'));

  test('état initial : Idle', () {
    build(_FakeActionClient());
    expect(bloc.state, isA<ActionIdle>());
  });

  test('clic accepté : Sending puis Running, qui dure jusqu à la fin de '
      'l activité', () async {
    final client = _FakeActionClient();
    build(client);

    click();
    await _tick();
    expect(emitted, [isA<ActionSending>(), isA<ActionRunning>()]);
    expect((bloc.state as ActionRunning).name, 'block_release');
    expect(client.calls, [(action: 'block_release', surface: 'actions')]);

    bloc.add(const ActionActivityChanged(busy: true));
    await _tick();
    expect(bloc.state, isA<ActionRunning>());

    bloc.add(const ActionActivityChanged(busy: false));
    await _tick();
    expect(bloc.state, isA<ActionIdle>());
  });

  test(
    'une fin d activité vue avant tout travail ne termine pas Running',
    () async {
      build(_FakeActionClient());
      click();
      await _tick();

      bloc.add(const ActionActivityChanged(busy: false));
      await _tick();

      expect(bloc.state, isA<ActionRunning>());
    },
  );

  test(
    'l activité terminée pendant l envoi termine Running aussitôt acceptée',
    () async {
      final client = _FakeActionClient()..gate = Completer<void>();
      build(client);
      click();
      await _tick();
      expect(bloc.state, isA<ActionSending>());

      bloc.add(const ActionActivityChanged(busy: true));
      bloc.add(const ActionActivityChanged(busy: false));
      await _tick();
      client.gate!.complete();
      await _tick();

      expect(bloc.state, isA<ActionIdle>());
    },
  );

  test('un clic pendant Sending ou Running est ignoré', () async {
    final client = _FakeActionClient()..gate = Completer<void>();
    build(client);
    click();
    await _tick();
    click('validate_release');
    click();
    await _tick();
    client.gate!.complete();
    await _tick();
    click('validate_release');
    await _tick();

    expect(client.calls, hasLength(1));
    expect(bloc.state, isA<ActionRunning>());
    expect((bloc.state as ActionRunning).name, 'block_release');
  });

  test('un identifiant hors contrat est ignoré', () async {
    final client = _FakeActionClient();
    build(client);

    click('delete_release');
    await _tick();

    expect(client.calls, isEmpty);
    expect(emitted, isEmpty);
  });

  test('busy puis accepted : réessai, puis Running', () async {
    final client = _FakeActionClient([
      CanvasActionResult.busy,
      CanvasActionResult.noSession,
    ]);
    build(client);

    click();
    await _tick(100);

    expect(client.calls, hasLength(3));
    expect(emitted, [isA<ActionSending>(), isA<ActionRunning>()]);
  });

  test('busy, activité vraie puis fausse, puis accepted : reste Running '
      'jusqu\'au prochain passage de busy à idle (D6)', () async {
    final client = _FakeActionClient([
      CanvasActionResult.busy,
      CanvasActionResult.accepted,
    ]);
    build(
      client,
      const CanvasActionSettings(
        retries: 3,
        retryInterval: Duration(milliseconds: 60),
        maxDuration: Duration(seconds: 5),
      ),
    );

    click();
    await _tick(20);
    // Fin d'une délégation vocale pendant l'attente avant le réessai.
    bloc.add(const ActionActivityChanged(busy: true));
    bloc.add(const ActionActivityChanged(busy: false));
    await _tick(150);

    expect(client.calls, hasLength(2));
    expect(bloc.state, isA<ActionRunning>());

    bloc.add(const ActionActivityChanged(busy: true));
    bloc.add(const ActionActivityChanged(busy: false));
    await _tick();

    expect(bloc.state, isA<ActionIdle>());
  });

  test('réessais épuisés : Failed(busy) puis Idle, nombre borné', () async {
    final client = _FakeActionClient(List.filled(50, CanvasActionResult.busy));
    build(client);

    click();
    await _tick(200);

    expect(client.calls, hasLength(_fast.retries + 1));
    expect(emitted, [
      isA<ActionSending>(),
      isA<ActionFailed>().having(
        (s) => s.reason,
        'reason',
        CanvasActionFailure.busy,
      ),
      isA<ActionIdle>(),
    ]);
  });

  test('noSession épuisé : Failed(noSession)', () async {
    build(_FakeActionClient(List.filled(50, CanvasActionResult.noSession)));
    click();
    await _tick(200);
    expect(
      emitted.whereType<ActionFailed>().single.reason,
      CanvasActionFailure.noSession,
    );
  });

  test('refus et échec : Failed sans réessai, puis Idle', () async {
    for (final (result, reason) in [
      (CanvasActionResult.rejected, CanvasActionFailure.rejected),
      (CanvasActionResult.failed, CanvasActionFailure.unreachable),
    ]) {
      final client = _FakeActionClient([result]);
      build(client);
      click();
      await _tick();
      expect(client.calls, hasLength(1), reason: '$result');
      expect(emitted.whereType<ActionFailed>().single.reason, reason);
      expect(bloc.state, isA<ActionIdle>());
      await sub.cancel();
      await bloc.close();
    }
  });

  test('un clic est de nouveau possible après un échec', () async {
    final client = _FakeActionClient([CanvasActionResult.rejected]);
    build(client);
    click();
    await _tick();
    click();
    await _tick();

    expect(client.calls, hasLength(2));
    expect(bloc.state, isA<ActionRunning>());
  });

  test('la fermeture de session termine Running', () async {
    build(_FakeActionClient());
    click();
    await _tick();

    bloc.add(const ActionSessionClosed());
    await _tick();

    expect(bloc.state, isA<ActionIdle>());
  });

  test('le délai maximal termine Running', () async {
    build(
      _FakeActionClient(),
      const CanvasActionSettings(
        retries: 1,
        retryInterval: Duration(milliseconds: 5),
        maxDuration: Duration(milliseconds: 40),
      ),
    );
    click();
    await _tick(10);
    expect(bloc.state, isA<ActionRunning>());

    await _tick(80);

    expect(bloc.state, isA<ActionIdle>());
  });

  test('la remise à vide interrompt Running et rend la main', () async {
    final client = _FakeActionClient();
    build(client);
    click();
    await _tick();

    bloc.add(const ActionStageReset());
    await _tick();
    expect(bloc.state, isA<ActionIdle>());

    click('validate_release');
    await _tick();
    expect(client.calls, hasLength(2));
    expect(bloc.state, isA<ActionRunning>());
  });

  test('la remise à vide arrête les réessais en cours', () async {
    final client = _FakeActionClient(List.filled(50, CanvasActionResult.busy));
    build(
      client,
      const CanvasActionSettings(
        retries: 20,
        retryInterval: Duration(milliseconds: 20),
        maxDuration: Duration(seconds: 5),
      ),
    );
    click();
    await _tick(30);
    bloc.add(const ActionStageReset());
    await _tick(10);
    final seen = client.calls.length;
    await _tick(100);

    expect(client.calls, hasLength(seen));
    expect(bloc.state, isA<ActionIdle>());
  });

  test(
    'la réponse d une requête périmée par la remise à vide est ignorée',
    () async {
      final client = _FakeActionClient()..gate = Completer<void>();
      build(client);
      click();
      await _tick();
      bloc.add(const ActionStageReset());
      await _tick();
      client.gate!.complete();
      await _tick();

      expect(bloc.state, isA<ActionIdle>());
      expect(emitted.whereType<ActionRunning>(), isEmpty);
    },
  );

  test('close pendant l envoi ne lève rien', () async {
    final client = _FakeActionClient()..gate = Completer<void>();
    build(client);
    click();
    await _tick();

    await bloc.close();
    client.gate!.complete();
    await _tick();
  });

  group('décision prise (statut de la checklist)', () {
    const grace = _fast;

    void status(String s) => bloc.add(DecisionStatusObserved(s));

    test(
      'le statut qui change après un clic fixe l action comme faite',
      () async {
        build(_FakeActionClient(), grace);
        status('En attente');
        click();
        await _tick();
        status('Bloquée');
        await _tick();

        expect(bloc.state.doneAction, 'block_release');
        expect(bloc.state, isA<ActionRunning>());
      },
    );

    test('un nouveau changement de statut réactive l action', () async {
      build(_FakeActionClient(), grace);
      status('En attente');
      click();
      await _tick();
      status('Bloquée');
      await _tick();
      status('En attente');
      await _tick();

      expect(bloc.state.doneAction, isNull);
    });

    test('clic sans changement de statut, puis réécriture vocale tardive : '
        'pas de « fait »', () async {
      build(_FakeActionClient(), grace);
      status('En attente');
      click();
      await _tick();
      bloc.add(const ActionSessionClosed());
      await _tick();
      expect(bloc.state, isA<ActionIdle>());
      // Une demande vocale démarre une nouvelle activité.
      bloc.add(const ActionActivityChanged(busy: true));
      await _tick();

      status('Validée');
      await _tick();

      expect(bloc.state.doneAction, isNull);
    });

    test('le statut qui arrive après la fin de l activité, sans nouvelle activité, compte', () async {
      build(_FakeActionClient(), grace);
      status('En attente');
      click();
      await _tick();
      bloc.add(const ActionSessionClosed());
      await _tick(5);
      status('Bloquée');
      await _tick();

      expect(bloc.state.doneAction, 'block_release');
    });

    test('la remise à vide annule le clic en attente et la décision', () async {
      build(_FakeActionClient(), grace);
      status('En attente');
      click();
      await _tick();
      bloc.add(const ActionStageReset());
      await _tick();
      status('Bloquée');
      await _tick();
      expect(bloc.state.doneAction, isNull);

      click();
      await _tick();
      status('Validée');
      await _tick();
      expect(bloc.state.doneAction, 'block_release');
      bloc.add(const ActionStageReset());
      await _tick();
      expect(bloc.state.doneAction, isNull);
    });

    test('un échec d envoi annule le clic en attente', () async {
      build(_FakeActionClient([CanvasActionResult.rejected]), grace);
      status('En attente');
      click();
      await _tick();
      status('Bloquée');
      await _tick();

      expect(bloc.state.doneAction, isNull);
    });
  });
}
