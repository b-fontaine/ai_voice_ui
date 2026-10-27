---
id: proto-rtc-webtransport
title: Temps réel — WebTransport (HTTP/3), état 2026
tags: [rtc, webtransport, http3, quic]
status: verified
updated: 2026-10-26
sources: [https://webkit.org/blog/17862/webkit-features-for-safari-26-4/, https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API, https://www.utsubo.com/blog/frontier-web-apis-2026-production-ready, https://pub.dev/packages/quic_lib, https://pub.dev/packages/rk_quic]
links: [proto-rtc-transport-choice, proto-rtc-flutter-packages]
---
# WebTransport : prometteur, mais aucun fournisseur de voix IA ne l'utilise

WebTransport (W3C, sur HTTP/3 et QUIC) offre des streams multiplexés **sans head-of-line blocking** et des datagrammes non fiables. Il se situe à mi-chemin entre WebSocket et le DataChannel WebRTC, sans la complexité d'ICE et SDP.

## État au 2026-10-26
- Safari 26.4 ajoute WebTransport (notes WebKit : « Safari 26.4 adds support for WebTransport »). MDN affiche **« Baseline 2026, Newly available » depuis mars 2026**, avec la mention « Some parts of this feature may have varying levels of support ».
- Des divergences entre moteurs (certificats, sous-parties de l'API) sont signalées par des blogs (source secondaire).

## Côté Dart/Flutter
- `quic_lib` 1.13.0 : pile QUIC, HTTP/3, WebTransport (et libp2p) en pur Dart, sans dépendance native. Plateformes Android, iOS, Linux, macOS et Windows. **Pas de cible web**, car le navigateur n'expose pas d'UDP brut.
- `rk_quic` 0.4.0 (spherex.kz) : QUIC/WebTransport via `dart:ffi` vers une bibliothèque Rust (quinn + rustls). Serveur, et client depuis 0.3.0. Package jeune.
- Aucun package trouvé ne s'appuie sur l'API WebTransport du **navigateur** pour Flutter web.

## Verdict (opinion)
- Ni OpenAI ni Gemini n'exposent d'endpoint WebTransport pour leurs modèles Live : WebTransport n'est **pas pertinent pour la voix** aujourd'hui.
- À surveiller pour un futur canal app ↔ orchestrateur à faible latence. En attendant, WebSocket ou SSE suffisent.

⚠️ **Pièges**
- Les proxys d'entreprise bloquent souvent l'UDP/443. Il faut toujours prévoir un repli sur WebSocket.
