// Spike SP-03 : preuve de bout en bout genui_a2a 0.10.1 + genui 0.10.4
// contre l'agent Go réel (processus lancé par le test). Code jetable.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_a2a/genui_a2a.dart';

const _agentBinary = String.fromEnvironment('AGENT_BIN');
const _pngDir = String.fromEnvironment('PNG_DIR');

Future<int> _freePort() async {
  final s = await ServerSocket.bind('127.0.0.1', 0);
  final p = s.port;
  await s.close();
  return p;
}

void main() {
  late Process agent;
  late Uri url;
  final sentToAgent = <ChatMessage>[];

  setUp(() async {
    // Le binding de test force HTTP 400 ; on rétablit le vrai HttpClient.
    HttpOverrides.global = null;
    expect(_agentBinary, isNotEmpty, reason: 'passer --dart-define=AGENT_BIN=');
    final port = await _freePort();
    agent = await Process.start(_agentBinary, ['-port', '$port']);
    agent.stderr.transform(const SystemEncoding().decoder).listen(stderr.write);
    agent.stdout.transform(const SystemEncoding().decoder).listen(stdout.write);
    url = Uri.parse('http://127.0.0.1:$port');
    // Attend que la carte soit servie.
    for (var i = 0; i < 50; i++) {
      try {
        final c = HttpClient();
        final r = await (await c.getUrl(url.resolve('/.well-known/agent-card.json'))).close();
        await r.drain<void>();
        c.close();
        if (r.statusCode == 200) break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    sentToAgent.clear();
  });

  tearDown(() {
    agent.kill(); // SIGTERM sur le seul PID lancé
  });

  testWidgets('rend la surface puis fait l\'aller-retour de l\'action validate',
      (tester) async {
    // Créé dans la zone réelle : sinon ses continuations restent dans la
    // zone FakeAsync de testWidgets et ne s'exécutent jamais sans pump.
    final connector = (await tester.runAsync(() async => A2uiAgentConnector(url: url)))!;
    final controller = SurfaceController(catalogs: [BasicCatalogItems.asCatalog()]);
    late final A2uiTransportAdapter transport;
    transport = A2uiTransportAdapter(onSend: (msg) async {
      sentToAgent.add(msg);
      await connector.connectAndSend(msg,
          clientCapabilities: controller.clientCapabilities);
    });
    final subs = <StreamSubscription<Object?>>[
      connector.stream.listen(transport.addMessage),
      connector.textStream.listen(transport.addChunk),
    ];
    final errors = <Object>[];
    subs.add(connector.errorStream.listen(errors.add));
    final conversation = Conversation(controller: controller, transport: transport);
    addTearDown(() async {
      for (final s in subs) {
        await s.cancel();
      }
      conversation.dispose();
      controller.dispose();
      connector.dispose();
    });

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: ListenableBuilder(
              listenable: conversation.state,
              builder: (_, _) => Column(children: [
                for (final id in conversation.state.value.surfaces)
                  Expanded(child: Surface(surfaceContext: controller.contextFor(id))),
              ]),
            ),
          ),
        ),
      ),
    ));

    // --- S3 : message utilisateur -> réseau réel -> surface ---
    await tester.runAsync(() async {
      await conversation.sendRequest(ChatMessage.user('bonjour'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(errors, isEmpty);
    expect(find.byType(Surface), findsOneWidget);
    expect(find.text('Sessions sans crash'), findsOneWidget);
    expect(find.text('99,57 %'), findsOneWidget);
    expect(find.text('validé'), findsNothing);
    expect(sentToAgent, hasLength(1));
    await _snap(tester, key, 'sp03_avant.png');

    // --- S4 : clic sur le bouton -> onSubmit -> onSend -> connectAndSend ---
    await tester.tap(find.byType(ElevatedButton));
    // L'abonnement onSubmit vit dans la zone FakeAsync : il faut alterner
    // temps réel (E/S) et pump (continuations de la zone fake).
    for (var i = 0; i < 20 && find.text('validé').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(errors, isEmpty);
    expect(sentToAgent, hasLength(2));
    final part = sentToAgent[1].parts.single;
    expect(part.isUiInteractionPart, isTrue);
    expect(part.asUiInteractionPart!.interaction, contains('"validate"'));
    expect(find.text('validé'), findsOneWidget);
    await _snap(tester, key, 'sp03_apres.png');

    // Laisse expirer le timer de 15 s armé par genui_a2a dans la zone fake.
    await tester.pump(const Duration(seconds: 20));
  });
}

Future<void> _snap(WidgetTester tester, GlobalKey key, String name) async {
  if (_pngDir.isEmpty) return;
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$_pngDir/$name').writeAsBytes(data!.buffer.asUint8List());
  });
}
