# 011 — Interaction vocale et corrections de l'essai au micro

**Backlog** : EP-02, EP-03, EP-04, EP-06 (corrections après J6). **Jalon** : avant J7 (ordre du porteur : 010 → 011 → 012 → 013 → J7).
**Décisions** : [pdr-0069](../../product/decisions/pdr-0069-voice-interruption-hybrid-stop-011.md) (coupure vocale hybride), [pdr-0071](../../product/decisions/pdr-0071-act2-focus-memory-act-indicator-click-feedback.md) (mémoire de focus, indicateur d'acte, retour au clic), [pdr-0073](../../product/decisions/pdr-0073-011-voice-interaction-details-assistant-decided.md) (détails tranchés par la boucle, pdr-0062).
**Sources** : [diagnostic de l'essai au micro](../../product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md).

## Objectif
Rendre tenables les Must d'interaction vocale révélés par l'essai au micro du 2026-10-30 : couper la parole à l'IA et « Stop » (FR-13, FR-14, FR-15, FR-16, FR-19), demande d'acte 2 en deux tours (Q-74), indicateur d'acte automatique, retour visuel fort au clic (FR-08), plus quatre corrections sans décision (fenêtre de demande, motif des refus, consignes vocales, idempotence du clic).

## Périmètre
1. **Fenêtre de demande** (bogue `window.go:77`) : un mot commencé à l'offset de la délégation n'est plus perdu (marge configurable + brève attente des deltas tardifs).
2. **Mémoire de focus** (Q-74, pdr-0071) : par canevas, dernière intention réussie (plateforme, vue) transmise aux agents ; « compare avec la 3.3 » sans plateforme hérite de la plateforme affichée ; sans focus le refus reste.
3. **Motif des refus journalisé** : le motif fermé de la `ScopeError` apparaît dans le journal de l'orchestrateur (jamais dans `detail`, qui reste fermé).
4. **« Stop »** (FR-16, pdr-0069) : détecteur de mots d'arrêt dans la transcription d'entrée (liste par configuration) → annulation des délégations en vol sans fermer la session, retrait des surfaces inachevées (les complètes restent, RG-14), événement `voice.interrupted` sur l'app-channel.
5. **Couper la parole** (FR-13, FR-19, pdr-0069) : consigne vocale (se taire quand le speaker parle, attendre la fin de phrase) ; l'app, à `voice.interrupted`, coupe aussitôt la piste audio distante, l'orbe passe « Interrompue » puis « Écoute » et la réplique de l'IA est tronquée.
6. **Indicateur d'acte automatique** (pdr-0071) : règle monotone `StageActReached` ; acte 2 à l'apparition de la surface `actions`, acte 3 au clic accepté ; le clic manuel corrige ; la remise à vide ramène à 1 ; sans effet en rejeu.
7. **Retour au clic** (pdr-0071) : statut de décision très visible et sans troncature, bouton « fait » (désactivé, ✓), état « en cours » ; clic idempotent (action déjà en place : pas de réannonce).

## Hors périmètre
- Faire taire à la souris / raccourci (FR-20, S-09), micro coupé (FR-12), correction « Non, plutôt iOS » en vol (FR-17 reste partielle) : J7.
- Compositeur LLM et CrashList (012), design (013).
- Réglage de la fin de tour de GPT-Live (limite du fournisseur, atténuée par consigne).

## Scénarios d'acceptation (à automatiser)
Nouveaux, dans `product/functional/features/` (ajoutés à la clôture, pdr-0062 pour l'écart) : sources S-05, S-06, S-08 de `barge-in.feature`, plus :
- **K-01** (Go) « Compare avec la 3.3 » après « Concentre-toi sur Android » donne la comparaison dans `/kpi`, `/reviews`, `/trend`, `/checklist` ; sans focus : refus `rejected`.
- **K-02** (Go) un mot dit à l'offset de la délégation est dans la demande.
- **K-03** (Go) S-06 : « Stop » pendant deux surfaces sur quatre en construction → annulation, deux `deleteSurface`, deux complètes intactes, `voice.interrupted` publié, session ouverte.
- **K-04** (Go) « stop » dans un mot (« stoppé », « bus stop ») ne déclenche pas.
- **K-05** (Flutter) `voice.interrupted` → piste distante coupée, orbe « Interrompue » puis « Écoute », réplique tronquée, surfaces inchangées (S-05).
- **K-06** (Flutter) indicateur : acte 2 à l'apparition de `actions`, acte 3 au clic accepté, jamais en arrière, remise à vide → 1, rejeu sans effet.
- **K-07** (Flutter) le statut « Bloquée » est visible entier et le bouton passe à « fait » ; un second clic ne renvoie rien.
