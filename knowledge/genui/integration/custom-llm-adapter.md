---
id: genui-custom-llm-adapter
title: Brancher genui sur un LLM non-Google (adaptateur custom)
tags: [genui, openai, llm, adapter, integration]
status: verified
updated: 2026-10-28
sources: [https://docs.flutter.dev/ai/genui/get-started, https://github.com/flutter/genui/tree/main/examples/simple_chat, https://github.com/flutter/genui/blob/main/packages/genui/lib/src/interfaces/transport.dart]
links: [genui-architecture, genui-prompt-builder, genui-user-actions, genui-voice-bridge, proj-avw-genui-bridge, proj-avw-risks, rt-tool-calling-voice]
---
# Pour tout autre LLM : implémenter `onSend` ou `Transport`, et pousser le texte dans l'adaptateur

C'est la voie officielle n°3 (« Build your own »). genui n'exige qu'un flux de **texte** contenant du JSON A2UI (JSONL ou blocs). `A2uiParserTransformer` sépare le texte libre des messages. L'exemple officiel `simple_chat` le fait avec `dartantic_ai`, multi-fournisseurs.

Patron de l'exemple (`SimpleChatA2aTransport implements Transport`) :
```dart
class OpenAiUiTransport implements Transport {
  final _adapter = A2uiTransportAdapter();
  final _history = <Map<String, String>>[];   // historique géré par vous
  @override Stream<A2uiMessage> get incomingMessages => _adapter.incomingMessages;
  @override Stream<String> get incomingText => _adapter.incomingText;
  @override Future<void> sendRequest(ChatMessage m) async {
    final text = m.parts.map((p) => p.isUiInteractionPart
        ? p.asUiInteractionPart!.interaction : (p is TextPart ? p.text : '')).join();
    _history.add({'role': 'user', 'content': text});
    final buf = StringBuffer();
    await for (final c in myOpenAiClient.stream(_history)) { buf.write(c); _adapter.addChunk(c); }
    _history.add({'role': 'assistant', 'content': buf.toString()});
  }
  @override void dispose() => _adapter.dispose();
}
```
`myOpenAiClient` désigne votre client HTTP ou SDK : c'est un nom fictif. `A2uiMessage` s'importe de `package:a2ui_core` en genui 0.10.4, et de `package:genui/a2ui_core.dart` à partir de 0.10.6.

- Le prompt système vient de `PromptBuilder.systemPromptJoined()`, à placer en tête de l'historique.
- **Variante tool calling :** déclarer un outil (`render_ui`) dont les arguments sont un message A2UI, puis `_adapter.addMessage(A2uiMessage.fromJson(args))`. Le JSON est mieux structuré, mais il faut maintenir le schéma de l'outil (opinion ; c'était l'approche `surfaceUpdate` d'ai_voice_widget, proj-avw-genui-bridge).
- La clé API ne doit jamais être dans l'app : passer par un proxy backend ou des clés éphémères (cf. proj-avw-risks).

⚠️ Pièges
- L'historique est **à votre charge** : genui n'en garde pas pour le LLM.
- Une réponse non streamée marche aussi (un seul `addChunk`), mais le rendu progressif est perdu.
