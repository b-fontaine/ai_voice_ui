# 002 — SP-02 : session GPT-Live par relais SDP (spike réduit)

> **En bref.** Spike (pas de Gherkin ni de revue d'architecte). Il établit, preuves à l'appui et sur un vrai appel `gpt-live-1`, si une session GPT-Live s'ouvre en français par **relais SDP côté backend, sans clé dans l'app**, quel **mode de délégation** convient (Q-47), d'où vient le **niveau audio de l'orbe** sans seconde capture micro (Q-43), et si le **barge-in** coupe l'IA. Ses résultats alimentent Q-43, Q-47 et Q-53.

- **Jalon** : J1 (spikes réduits), prépare J2 (`product/roadmap/spikes.md`, ligne SP-02)
- **Exigences visées** : FR-13, NFR-01, NFR-09 ; questions Q-43, Q-47, Q-53
- **Décisions applicables** : pdr-0012 (voix OpenAI, relais SDP, aucune clé dans l'app), pdr-0041 (backend dans ce dépôt, local, sans authentification utilisateur), pdr-0029 (clé dans un `.env` non versionné), pdr-0030 (budget LLM), adr-0003-backend-go, pdr-0010 (versions figées)
- **Hors périmètre** : intégration dans `apps/` ou `backend/` (le code est jetable, sous `spikes/sp02-gpt-live/`), orchestrateur, agents A2A, catalogue, application Flutter

## Questions
1. **Session sans clé dans l'app.** Un client WebRTC qui n'a pas la clé peut-il ouvrir une session `gpt-live-1` en français en passant son offre SDP à un relais qui détient la clé ?
2. **Mode de délégation (Q-47).** `client` (l'orchestrateur reçoit `session.delegation.created` et répond par `session.commentary.append`) ou `responses` (modèle Responses géré par OpenAI) : que reçoit-on, que peut-on injecter, avec quel délai ? (Le libellé de Q-47 dit « `decisions` » ; la doc dit `responses` : à corriger.)
3. **Niveau audio de l'orbe (Q-43).** Peut-on obtenir le niveau de la voix de l'IA sans seconde capture micro : copie sideband (`session.output_audio.delta`, PCM16 24 kHz) ou piste WebRTC distante ?
4. **Barge-in.** Quand l'utilisateur parle pendant que l'IA parle, l'IA se tait-elle, et en combien de temps ? (Essai automatisé avec voix synthétique, puis essai réel avec le porteur sur l'enceinte du PC : alerte précoce RD-6.)
5. **Durée de session (Q-53).** Durée maximale observée et raison de clôture (`expired`…), si l'essai la rencontre.

## Critère de succès (spikes.md)
3 essais (au lieu de 10) : session ouverte sans clé dans l'app ; mode de délégation établi ; source du niveau audio de l'orbe établie ; essai de barge-in. Résultat ❌/⚠️ consigné avec la cause exacte (accès au modèle, format, événement manquant…).

## Méthode
- **Relais Go** (`spikes/sp02-gpt-live/relay/`) : `POST /session` reçoit l'offre SDP, appelle `POST https://api.openai.com/v1/live/sessions` avec la clé lue dans l'environnement (jamais journalisée, jamais renvoyée), renvoie l'answer SDP et garde `session.id` ; s'attache au sideband (`/attach`) et journalise les événements horodatés en JSONL (sans secret).
- **Client Go** (`spikes/sp02-gpt-live/client/`, `pion/webrtc/v4`) : joue le rôle de l'app (aucune clé), envoie de la parole synthétisée (TTS OpenAI au format Opus/Ogg, joué comme piste audio), mesure l'audio reçu.
- **Phrases de test** : synthétisées en français avec le TTS d'OpenAI (quelques centimes), enregistrées hors dépôt (scratchpad), sans donnée personnelle.
- **Budget** : `tools/loop/openai-budget.sh check <estimation>` avant chaque appel payant, `add` avec le coût réel après (usage renvoyé par l'API), registre `specs/openai-spend.tsv` committé. Estimation initiale : ≤ 1,5 € pour l'ensemble.
- **Essai réel** avec le porteur (micro et enceinte du PC) : après les essais automatisés, une seule session courte.

## Critères d'acceptation
- [ ] Questions 1 à 4 tranchées par des essais reproductibles (commande et sortie citées dans `status.md`)
- [ ] Aucune clé dans le client, le dépôt ni les journaux (vérifié par recherche dans les journaux et le diff)
- [ ] Dépense réelle enregistrée dans `specs/openai-spend.tsv`
- [ ] Faits vérifiés versés dans `knowledge/` (kb-curate), sans référence au produit
- [ ] Résultat ✅/❌/⚠️ inscrit dans `product/roadmap/spikes.md` ; Q-43 et Q-47 : proposition de décision (`product-decide`) à valider par le porteur
- [ ] `tools/loop/gate.sh --full` vert à la clôture

## Questions ouvertes
- Q-43 et Q-47 se tranchent avec les résultats de ce spike : arbitrages du porteur, sauf si une seule réponse découle des faits.
- Accès de la clé du porteur à `gpt-live-1` : non vérifié avant le premier appel.
