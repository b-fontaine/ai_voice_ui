---
id: genui-firebase-ai
title: Brancher genui sur Gemini via Firebase AI Logic
tags: [genui, gemini, firebase, integration]
status: verified
updated: 2026-10-26
sources: [https://docs.flutter.dev/ai/genui/get-started, https://pub.dev/packages/firebase_ai, https://github.com/flutter/genui/tree/main/packages/genui/skills/integrate-genui-firebase]
links: [genui-architecture, genui-prompt-builder, genui-custom-llm-adapter, genui-a2a-connector, proj-avw-risks, rt-gemini-firebase-ai-dart]
---
# Firebase AI Logic : la voie « client seul », sans serveur

C'est la voie officielle n°1 pour un LLM appelé depuis l'app Flutter. `firebase_ai` est en **5.1.0** (pub.dev, 2026-10-23). Il n'y a plus de `FirebaseAiContentGenerator` : on écrit soi-même `onSend`.

```dart
// dart pub add genui firebase_ai
final pb = PromptBuilder.chat(catalog: catalog, systemPromptFragments: ['…']);
final model = FirebaseAI.vertexAI().generativeModel(       // ou FirebaseAI.googleAI()
  model: 'gemini-3.5-flash',                                // modèle de la doc, oct. 2026
  systemInstruction: Content.system(pb.systemPromptJoined()),
);
final chat = model.startChat();
late final A2uiTransportAdapter transport;
transport = A2uiTransportAdapter(onSend: (msg) async {
  final text = msg.parts.map((p) => p.isUiInteractionPart
      ? p.asUiInteractionPart!.interaction
      : (p is TextPart ? p.text : '')).join();
  await for (final r in chat.sendMessageStream(Content.text(text))) {
    transport.addChunk(r.text ?? '');
  }
});
```

- Le skill officiel conseille `import 'package:genui/genui.dart' hide TextPart;`, car `TextPart` existe aussi dans `firebase_ai`.
- iOS/macOS : ajouter l'entitlement `com.apple.security.network.client`, et vérifier la version minimale de plateforme imposée par Firebase (Podfile).

⚠️ Pièges
- Les exemples officiels se contredisent sur les noms (`systemPrompt` vs `systemPromptJoined()`, paramètre `instructions:` dans le skill). Se fier à l'API de la version épinglée.
- La doc genui ne montre le streaming qu'en commentaire, via `model.generateContentStream(...)`. L'usage de `ChatSession.sendMessageStream` ci-dessus est une adaptation (non testée) ; le skill officiel utilise `sendMessage` non streamé.
- Clés et App Check : la sécurité repose sur Firebase App Check, pas sur une clé cachée dans l'app (cf. proj-avw-risks).
