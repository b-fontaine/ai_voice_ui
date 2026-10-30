---
id: pdr-0069-voice-interruption-hybrid-stop-011
title: "PDR-0069 — Interruption vocale et « Stop » : consigne au modèle, détection par l'orchestrateur, coupure locale"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [p-rm-open-questions, p-rm-roadmap, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, p-fn-requirements, p-ar-agents-protocols, rt-barge-in, rt-gpt-live-sideband, pdr-0025-top-bar-speaker-and-ai-lines, pdr-0037-voice-brise-delegated-instructions, pdr-0033-optional-shortcuts-mouse-first]
tags: [pdr, decision, voix, barge-in, stop]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire après l'essai au micro)"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0069 — Interruption vocale et « Stop » : consigne au modèle, détection par l'orchestrateur, coupure locale

> **En bref.** Approche hybride dès la fonctionnalité 011 : le modèle se tait quand le speaker parle (consigne) ; l'orchestrateur repère « stop / annule / arrête » dans la transcription d'entrée, annule les délégations en vol, retire les surfaces inachevées et publie un événement d'interruption ; l'app coupe aussitôt le son de l'IA (piste distante) et passe l'orbe à « Interrompue » puis « Écoute ». Tranche Q-42, Q-40, Q-67 ; Q-41 close comme conforme.

Part de l'assistant : recommandation, mise en forme et consignation de la parole du porteur.

## Contexte
FR-13, FR-16 et FR-19 sont des Must (J7 initialement). L'essai au micro montre que couper la parole ou dire « stop » ne produit rien : GPT-Live traite l'interruption comme une fin de phrase, GPT-Live n'émet aucun événement d'interruption (Q-40) et l'arrêt audible est retardé par le tampon de lecture (Q-67). Les bruits ambiants n'ont en revanche aucun effet (FR-18 tenu, Q-41).

Observations du porteur (conversation du 2026-10-30) : « Je n'ai pas vu la comparaison dans l'essai que tu m'as demandé ; Le composant Crashlist n'est jamais apparu, même après l'avoir demandé explicitement ; Lui dire stop ou essayer de lui couper la parole ne fonctionne pas ; Quand je dis stop, rien ne se passe ; Quand je m'interrompts, elle compte ça comme une fin de phrase ; par contre, elle ne repère que ma voix, les bruits autour n'ont pas d'impact ; C'est toujours écrit Acte 1/3 en haut à droite, même après avoir bloqué la release ; Cliquer sur "Bloquer la release" n'a eu un effet qu'après le discours de l'IA ».

Diagnostic complet (contre-vérifié sur les journaux des sessions) : [diagnostic de l'essai au micro](_archive/2026-10-30-essai-micro-diagnostic.md).

## Options
1. **Hybride dès 011** (retenue) : consigne au modèle + détection de mot-clé par l'orchestrateur + coupure locale côté client.
2. Attendre J7 et mesurer d'abord.
3. Se fier au seul comportement du modèle.

## Décision
Question posée : « Couper la parole et « Stop » (FR-13, FR-16, FR-19, des Must) : comment les traiter, et quand ? » Réponse : « Hybride, dès 011 (Recommandé) ».
- **Consigne** : le modèle se tait dès que le speaker parle ; commentaires de l'IA raccourcis.
- **« Stop »** : l'orchestrateur repère « stop / annule / arrête » (liste injectée par configuration, pas codée en dur) dans la transcription d'entrée ; il annule les délégations en vol, retire les surfaces inachevées (garde les complètes, RG-14) et publie un événement d'interruption à l'app.
- **Client** : coupe aussitôt localement le son de l'IA (piste distante) et passe l'orbe à « Interrompue » puis « Écoute » (FR-19). La coupure locale côté client est acceptée (Q-67).
- **Bruits** : Q-41 close comme conforme (observation du porteur : les bruits ne l'interrompent pas ; FR-18 tenu).
- **Limite fournisseur à noter** : la fin de tour de GPT-Live n'est pas réglable ; consigne vocale « attends la fin de la phrase après une hésitation » en atténuation.

## Raisons
- Le porteur veut des Must fonctionnels pour le talk, pas un traitement tardif.
- Un mot-clé est déterministe et testable ; la coupure locale supprime le délai de lecture.

## Options écartées
- Attendre J7 : le défaut est déjà visible à l'essai.
- Décision du seul modèle : non fiable (observé).

## Conséquences
- Fonctionnalité **011** (interaction vocale et corrections de l'essai), avant J7.
- [p-fn-requirements](../functional/requirements.md) FR-13, FR-16, FR-19 ; [p-ar-agents-protocols](../architecture/agents-protocols.md) : événement d'interruption.
- Q-40, Q-42, Q-67 tranchées, Q-41 conforme.

## Réexaminer si
- Le mot-clé déclenche à tort en répétition, ou la coupure locale produit des artefacts audibles.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Q-42, Q-40, Q-67 tranchées ; Q-41 close comme conforme. Réponse : « Hybride, dès 011 (Recommandé) ». | Benoît FONTAINE (porteur), conversation |

Archive brute : [diagnostic de l'essai au micro](_archive/2026-10-30-essai-micro-diagnostic.md).
