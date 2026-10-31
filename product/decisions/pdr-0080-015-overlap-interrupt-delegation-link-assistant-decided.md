---
id: pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided
title: "PDR-0080 — 015 (011b) : détails du déclencheur de chevauchement et de la liaison animée de délégation"
area: decisions
status: validated
updated: 2026-10-31
sources: [specs/015-j7-overlap-interrupt-delegation-link/spec.md, specs/015-j7-overlap-interrupt-delegation-link/plan.md, knowledge:rt-barge-in, knowledge:rt-transcription, knowledge:rt-echo-cancellation]
links: [pdr-0077-011b-overlap-interrupt-delegation-link, pdr-0069-voice-interruption-hybrid-stop-011, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0076-014-silence-mic-correction-assistant-decided, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, p-ar-voice-interruption, p-ar-app-channel-contract, p-fn-screen, p-rm-open-questions]
tags: [pdr, decision, voix, interruption, chevauchement, rail, liaison, 015, 011b]
decision_status: acceptée
decided_on: 2026-10-31
decided_by: "Assistant (délégation du porteur, pdr-0062)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0080 — 015 (011b) : détails du déclencheur de chevauchement et de la liaison animée de délégation

> **En bref.** [pdr-0077](pdr-0077-011b-overlap-interrupt-delegation-link.md) (porteur) a décidé le quoi : couper l'IA dès que le speaker parle (Q-77), dessiner la liaison de délégation (Q-85). Cette PDR consigne le comment, tranché par la boucle sous pdr-0062 : aucun choix de périmètre, de mise en scène, de budget ni de fournisseur. À contester par le porteur.

## Contexte
Q-77 option B et Q-85 sont tranchées. La fiche et la PDR fixent les règles (mot significatif, écho ignoré, mots vides exclus, longueur minimale configurable, interrupteur `VOICE_OVERLAP_INTERRUPT` activé par défaut, connecteur animé orchestrateur → agent) mais pas leur réalisation. [rt-barge-in] : GPT-Live n'émet aucun événement d'interruption côté serveur utilisable ; [rt-transcription] : les deltas d'entrée portent `start_ms`.

## Hypothèses
- ⚠️ Hypothèse non confirmée : sans AEC, une transcription d'entrée de l'écho de l'IA reprend ses mots à l'identique (le filtre par mots suffit). → Q-80.
- ⚠️ Hypothèse non confirmée : la latence de la coupure est d'environ 1 s (délai de transcription d'entrée). → Q-80.

## Décision
- **D1** Le déclencheur est un troisième genre (`Overlap`) du classifieur d'énoncé unique de 014 : un seul minuteur, un seul énoncé, anti-rebond partagé. **Priorité** : correction, puis arrêt (y compris un début de mot d'arrêt), puis chevauchement ; un énoncé ne produit jamais deux `voice.interrupted`.
- **D2** « L'IA parle » = un bloc d'audio de sortie de niveau ≥ `VOICE_OVERLAP_SPEAKING_LEVEL` (le flux est continu, silence compris : sa seule présence ne prouve rien) ou un delta de transcription de sortie a eu lieu dans `VOICE_OVERLAP_SPEAKING_WINDOW` (horloge injectée). La garde est verrouillée à l'ouverture de l'énoncé. Sinon, une phrase du speaker est un tour de parole ordinaire.
- **D3** Seuls les jetons fermés sont jugés (les deltas sont des fragments de mot). Mot significatif : hors écho, un nombre l'est quelle que soit sa longueur (la dispense ne porte ni sur l'écho ni sur la liste ignorée), sinon longueur ≥ `VOICE_OVERLAP_MIN_WORD_LEN`, hors `VOICE_OVERLAP_IGNORE_WORDS`, hors écho (mots de la transcription de **sortie** de la fenêtre média `VOICE_OVERLAP_ECHO_WINDOW`) ; `VOICE_OVERLAP_MIN_WORDS` mots distincts. Valeurs de départ dans le compose, à régler en répétition.
- **D4** Effet : `at_ms` = début du premier delta de l'énoncé ; `voice.interrupted {cause: overlap}` publié **toujours**, puis `Supersede` (jamais `Interrupt`) : l'exécution antérieure est annulée avec les effets de 014 (surfaces complètes conservées), la demande du speaker est conservée et planifiée. Aucun message n'est envoyé au fournisseur.
- **D5** App : `overlap` est traité comme `correction` (fin à la première délégation d'offset ≥ `at_ms`, sinon au silence de reprise) ; reçu alors que l'orbe est en `Listening` (le fournisseur coupe sa voix avant notre message), il donne `Interrupted` puis `Listening` aussitôt ; reçu pendant une interruption en cours (`Interrupted`), il la **requalifie** en `overlap` avec son `at_ms` (fin par la délégation d'offset ≥ `at_ms` ou par le silence de reprise) sans la terminer (amendement de la revue du code, R10). Anti-rebond asymétrique : un Stop n'est jamais filtré par un Overlap. Une correction dite pendant que l'IA parle coupe aussi la voix.
- **D6** Liaison de délégation : trait pointillé animé du bord de la tuile de l'orchestrateur à la tuile de chaque agent « en attente » ou « en cours » (arc au-dessus des pastilles, rien n'est couvert), animation coupée par `SceneMotionScope.disabled`, repeinture isolée. Elle disparaît à la fin de l'état. Aucun libellé ajouté.

## Raisons
- Un classifieur unique évite deux minuteurs et deux voies de publication qui se contrediraient (014 P3).
- `Supersede` plutôt que `Interrupt` : la demande du speaker, prononcée par-dessus la voix de l'IA, doit être planifiée.
- Le filtre d'écho par mots est la seule protection logicielle disponible sans AEC ([rt-echo-cancellation]).

## Options écartées
- Chevauchement par détection d'activité vocale sur l'audio brut : le backend ne reçoit pas le micro (il passe par WebRTC jusqu'au fournisseur).
- Un envoi `response.cancel` au fournisseur : le comportement de GPT-Live à ce message n'est pas vérifié ([rt-gpt-live-sideband]) ; la coupure locale suffit.
- Liaison toujours visible (tous les agents du plan) : elle perdrait son sens de « délégation en cours ».

## Conséquences
- Documents mis à jour à la clôture de 015 : [p-ar-voice-interruption](../architecture/voice-interruption.md), [p-ar-app-channel-contract](../architecture/app-channel-contract.md), [p-fn-screen](../functional/screen.md).
- Nouvelles variables : `VOICE_OVERLAP_INTERRUPT`, `VOICE_OVERLAP_SPEAKING_WINDOW`, `VOICE_OVERLAP_ECHO_WINDOW`, `VOICE_OVERLAP_MIN_WORDS`, `VOICE_OVERLAP_MIN_WORD_LEN`, `VOICE_OVERLAP_IGNORE_WORDS`.

## Réexaminer si
- Un commentaire (« super ») par-dessus l'accusé de **sa propre** demande l'annule et laisse le canevas interrompu (pdr-0077 l'impose ; acquiescements dans la liste des mots ignorés) : à juger par le porteur.
- Fausses interruptions en répétition sur enceinte (monter `MIN_WORDS`, allonger `ECHO_WINDOW`, ou couper `VOICE_OVERLAP_INTERRUPT`) ; latence nettement supérieure à 1 s (Q-80) ; la liaison gêne la lecture du rail à la projection.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée (délégation pdr-0062), à l'étape « Définir » de 015 | Assistant (délégation du porteur, pdr-0062) |
| 2026-10-31 | D5 amendé à la revue du code (R10) : la règle de l'orbe ne met plus fin à une interruption en cours ; D3 : la dispense des nombres ne porte pas sur l'écho (R1) | Assistant (délégation du porteur, pdr-0062) |

Pas d'archive brute.
