---
id: rt-graceful-close
title: Fermeture propre d'une session voix
tags: [pattern, lifecycle, dispose, resources, bloc]
status: sourced
updated: 2026-10-30
sources: [https://github.com/flutter-webrtc/flutter-webrtc/blob/main/lib/src/native/rtc_peerconnection_impl.dart, https://developers.openai.com/api/docs/guides/live-conversations.md, https://ai.google.dev/gemini-api/docs/live-session, https://pub.dev/documentation/flutter_webrtc/latest/flutter_webrtc/Helper-class.html]
links: [rt-gpt-live-lifecycle, rt-gemini-session-limits, rt-flutter-webrtc-audio-routing, proj-avw-risks, di-dispose-method]
---
# Fermer proprement (et pouvoir redémarrer)

**GPT-Live** (doc officielle) :
1. Terminer le travail en cours, y compris les résultats d'outils.
2. Écouter `session.closed` **avant** d'envoyer `session.close`.
3. Envoyer `session.close` et ne plus rien soumettre.
4. Lire `usage.seconds` et `reason`.
5. Libérer le transport et l'audio. Sur timeout, journaliser la session comme « incomplète ».

**Gemini Live :** `await session.close()`, puis arrêt de l'enregistreur, puis arrêt et vidage du lecteur PCM.

**Côté flutter_webrtc** (opinion, ordre recommandé) :
1. Pour chaque piste locale : `track.stop()`.
2. `localStream.dispose()`.
3. `dataChannel.close()`.
4. `pc.close()`, puis `pc.dispose()`.
5. `renderer.srcObject = null` puis `renderer.dispose()`.
6. Android : `Helper.clearAndroidCommunicationDevice()`.

`close()` et `dispose()` d'un `RTCPeerConnection` sont deux appels natifs distincts (vérifié le 2026-10-30 dans `flutter_webrtc` 1.6.3, `rtc_peerconnection_impl.dart` : `close()` envoie `peerConnectionClose` ; seul `dispose()` annule l'abonnement à l'`EventChannel` et envoie `peerConnectionDispose`). Sans `dispose()`, un pair natif fuit à chaque session.

**Architecture** (opinion, contre les bugs d'ai_voice_widget) :
- Séparer `stop()` (fin de session, l'objet reste réutilisable) de `dispose()` (fin de vie). Ne pas fermer les `StreamController` dans `stop()`.
- Le runner est créé par session (scope factory), pas en singleton.
- `VoiceAgentBloc.close()` appelle bien `runner.stop()` (bug n°1 de [[proj-avw-risks]]).
- Un timeout de fermeture (par exemple 3 s) garantit la libération du micro même si `session.closed` n'arrive jamais.

## ⚠️ Pièges
- Avec `session.close`, les réponses en file sont annulées. Une réponse qui attend un résultat de fonction ne pourra plus continuer.
- iOS : la session audio reste active tant qu'une piste locale ou une PeerConnection subsiste. L'indicateur micro reste alors allumé.
