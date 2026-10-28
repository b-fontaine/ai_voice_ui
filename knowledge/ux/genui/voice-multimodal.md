---
id: ux-voice-multimodal
title: Voix + écran généré — barge-in et signaux d'écoute
tags: [voice, multimodal, barge-in, genui, ux]
status: verified
updated: 2026-10-27
sources: [https://developers.meta.com/horizon/design/voice/]
links: [rt-barge-in, rt-transcription, genui-voice-bridge, ma-filler-acknowledgements, ux-genui-streaming-loading]
---
# L'utilisateur doit pouvoir couper la parole et savoir quand le micro écoute

Les guidelines voix de Meta définissent le **barge-in** : l'utilisateur interrompt une réponse ou un prompt du système avec sa propre saisie, ce qui revient en général à parler par-dessus le système. Elles demandent aussi de rendre **l'activation du micro clairement perceptible**, par des **earcons** ou des indices conversationnels.

- Implémentation du barge-in côté Live : [[rt-barge-in]].
- Transcription des tours : [[rt-transcription]].
- Pont entre la voix et les surfaces GenUI : [[genui-voice-bridge]].
- Couvrir la latence d'un outil par une phrase d'attente : [[ma-filler-acknowledgements]].

## Recommandations voix + écran (opinion)
Aucune source primaire lue ne couvre l'affichage d'une transcription ni un retour visuel d'écoute : ce qui suit est une recommandation interne.
- **État d'écoute visible :** un composant DS unique affiche les états inactif, écoute, réflexion et parole. Il double l'earcon, qui ne suffit pas sur desktop sans casque ni pour un utilisateur malentendant.
- **Transcription affichée :** l'énoncé de l'utilisateur, puis la réponse de l'agent, s'affichent dans l'écran, pour vérifier ce qui a été compris.
- **Complémentarité :** l'écran généré porte le détail (tableau, formulaire, liste de choix), la voix le résume et dit où regarder. La voix ne lit pas le contenu de la surface.
- **Barge-in et surfaces :** une interruption arrête la parole et le streaming en cours ([[ux-genui-streaming-loading]]), mais ne détruit pas une surface déjà complète.
- **Saisie partagée :** ce qu'on dit et ce qu'on clique sur la surface aboutissent au même Bloc d'intention, pour ne pas avoir deux chemins concurrents.

## ⚠️ Pièges
- La définition de Meta dit « with their own input », pas strictement « parole ».
- Les guidelines Meta visent Horizon (XR) : leur transposition au desktop et au web n'est pas vérifiée.
- **Non vérifié :** aucune source primaire lue sur la transcription visible ou un retour visuel d'écoute (au 2026-10-27).
