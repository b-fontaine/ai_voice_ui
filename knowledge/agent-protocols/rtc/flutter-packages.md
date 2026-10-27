---
id: proto-rtc-flutter-packages
title: Temps réel — packages Flutter (WebRTC, WebSocket, SSE)
tags: [rtc, flutter, pub.dev, webrtc, websocket, sse]
status: verified
updated: 2026-10-26
sources: [https://pub.dev/packages/flutter_webrtc, https://pub.dev/packages/web_socket_channel, https://pub.dev/packages/web_socket_channel/changelog, https://pub.dev/packages/sse_channel, https://pub.dev/packages/genui_a2a, https://pub.dev/packages/ag_ui]
links: [proto-rtc-transport-choice, proto-a2a-dart-sdk, proto-agui-dart-sdk, proto-mcp-dart-sdks, rt-flutter-webrtc-overview, proj-avw-risks]
---
# Briques de transport Flutter (versions pub.dev au 2026-10-26)

| Besoin | Package | Version | Éditeur | Plateformes |
|---|---|---|---|---|
| WebRTC (audio + DataChannel) | `flutter_webrtc` | 1.6.3 | flutter-webrtc.org (vérifié) | Android, iOS, macOS, Windows, Linux ; web marqué supporté dans le tableau de fonctions |
| WebSocket | `web_socket_channel` | 3.0.3 | tools.dart.dev | toutes, web compris (`WebSocketChannel.connect`) |
| SSE (utilisé par genui_a2a) | `sse_channel` | 0.2.2 | jamiewest.dev | toutes, web compris |
| Client AG-UI (SSE) | `ag_ui` | 0.3.0 | community.ag-ui.com | toutes |
| Client MCP (Streamable HTTP) | `mcp_dart` | 2.4.3 | leehack.com | toutes (web : client HTTP seulement) |

## Règles d'architecture (opinion)
- Chaque transport est encapsulé dans la **couche data**, derrière une interface de repository, et injecté via `get_it`/`injectable`.
- Le domaine ne voit que des `Stream` typés, jamais `RTCPeerConnection` ou `WebSocketChannel`.
- Il faut un **seul propriétaire** du micro (WebRTC ou `record`) à la fois, sinon les deux runners se disputent l'AEC (voir proj-avw-risks).

⚠️ **Pièges**
- `web_socket_channel` 3.0.3 date d'environ 18 mois. Il est stable ; son implémentation web est passée à `package:web` en 2.4.1 « to support WebAssembly compilation ».
- `sse_channel` 0.2.2 date d'environ 12 mois ; `genui_a2a` l'épingle en `^0.2.2`.
