# VoiceBar
Barre vocale : orbe, transcription en direct, progression des actes, contrôles micro.

- Orbe `plasma` quand l'IA parle, `is-listening` (signal) quand le micro écoute.
- Transcription mot à mot (`data-type`) avec caret ; texte 20px pour le fond de salle. Jamais de « … » tronqué : 2 lignes max, la suite part dans l'UI.
- Actes en stepper 01 ✓ / 02 ✓ / 03 : le public sait où on en est.
- Nettoyer la transcription TTS (« je te dis ça, voici Voilà » dans l'acte 1 casse l'effet).
