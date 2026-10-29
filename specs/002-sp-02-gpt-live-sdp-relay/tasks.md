# 002 — Tâches (spike)

- [ ] S1 Lire le code d'`openai-go/v3` (`live`, sideband) et fixer les versions ; esquisse du relais · sortie : versions, signatures, noms d'événements notés dans `notes.md`
- [ ] S2 Relais Go + client `pion` : session ouverte sans clé dans le client, `session.started` reçu · sortie : journal JSONL (sans secret), coût noté
- [ ] S3 Délégation : essais `client` et `responses` avec une question en français (TTS) · sortie : événements reçus, réponses injectées, délais
- [ ] S4 Niveau audio : comparer la copie sideband (`output_audio.delta`) et la piste distante · sortie : niveaux mesurés, verdict pour l'orbe
- [ ] S5 Barge-in automatisé : parole synthétisée pendant que l'IA parle · sortie : délai de coupure mesuré
- [ ] S6 Essai réel avec le porteur sur l'enceinte du PC (une session courte) · sortie : ressenti et observations du porteur, citées
- [ ] S7 Consigner : `knowledge/`, `spikes.md`, Q-43/Q-47 (product-decide), `openai-spend.tsv`
- [ ] S8 Clôture : `gate.sh --full`, fusion, `publish.sh`
