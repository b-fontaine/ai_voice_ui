---
id: rt-transcription
title: Transcription en direct — sources par fournisseur
tags: [pattern, transcription, ui, openai, gemini]
status: verified
updated: 2026-10-26
sources: [https://developers.openai.com/api/docs/guides/live-conversations.md, https://ai.google.dev/gemini-api/docs/live-guide, https://pub.dev/documentation/firebase_ai/latest/firebase_ai/LiveServerContent-class.html]
links: [rt-gpt-live-lifecycle, rt-gemini-audio-vad, rt-barge-in, ma-flutter-event-bus]
---
# Transcription (affichage, logs, contexte de l'orchestrateur)

| Fournisseur | Utilisateur | Assistant |
|---|---|---|
| GPT-Live | `session.input_transcript.delta` | `session.output_transcript.delta` |
| Realtime | transcription d'entrée, si activée | `response.output_audio_transcript.delta` / `.done` |
| Gemini Live | `inputTranscription.text` (avec `inputAudioTranscription: {}`) | `outputTranscription.text` (avec `outputAudioTranscription: {}`) |

Les deltas GPT-Live portent `start_ms` et `end_ms` (temps depuis le début de la session). Il faut **les concaténer tels quels** : pas de trim ni d'ajout d'espace.

**Usage dans l'archi multi-agents** (opinion) :
- Le transcript est la **source de contexte de l'orchestrateur** : en mode délégation `client`, GPT-Live ne transmet pas la requête utilisateur.
- On le normalise dans un modèle domaine commun `TranscriptSegment{role, text, startMs?, final}`.

## ⚠️ Pièges
- GPT-Live : pas d'ID d'item ni de marqueur de fin de tour. On regroupe par rôle et par contiguïté temporelle.
- Les transcripts peuvent être faux ou incomplets (doc OpenAI). Ne pas déclencher d'action critique sur la seule base d'un fragment : demander confirmation.
- Gemini native audio : la langue de transcription de sortie est inférée.
