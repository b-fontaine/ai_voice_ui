---
id: proj-avw-risks
title: ai_voice_widget — bugs et anti-patterns à ne pas reproduire
tags: [project, anti-pattern, webrtc, security]
status: verified
updated: 2026-10-26
sources: ["~/septeo/ai_voice_widget (analyse locale du code, 2026-10-26)"]
links: [proj-avw-voice-runners, rt-ephemeral-keys, di-dispose-method, ma-real-tool-results, rt-graceful-close, rt-echo-cancellation, di-no-service-locator]
---
# Bugs et anti-patterns à ne pas reproduire

1. **`VoiceAi.stop()` ne ferme pas le runner** (`domain/voice_ai.dart:76-82`) : la peer connection et le micro restent actifs.
2. **Runners en singleton dont `dispose()` ferme les StreamControllers** : impossible de redémarrer ensuite. Prévoir `stop()`/`close()` distinct de `dispose()`, ou un scope factory.
3. **Double capture micro côté OpenAI** : `record` tourne en parallèle du `getUserMedia` WebRTC. Garder une seule source.
4. **La clé passée au widget est réutilisée pour Chat Completions** (GenUI OpenAI). Une clé longue durée côté client est une fuite. → Clés éphémères générées par un backend, chacune limitée à une API.
5. **Résultats d'outils factices `{"status":"ok"}`** renvoyés immédiatement : le vrai résultat de l'outil ne revient jamais au modèle.
6. **Modèles, voix, région et URL codés en dur.** `AiConfig` est un stub vide.
7. **Côté UI :**
   - `getIt` est appelé dans `build`.
   - Les abonnements aux flux ne sont pas annulés.
   - L'état `processing` n'est jamais émis.
   - Un `MergeStream` est recréé à chaque accès.
8. **Wrapper React :** il passe `initialData: {greeting}` alors que Flutter attend `apiKey`, `prompt`, `aiModel`. L'id DOM est codé en dur.
9. **Logs et heuristique :** `debugPrint` partout au lieu de `logging`. Le timer de 3 s pour détecter « l'IA parle » est fragile.
10. **Dépendances déclarées mais inutilisées :** `dartz`, `retrofit`, `google_generative_ai`.
