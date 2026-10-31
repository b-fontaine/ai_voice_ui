# Configuration de l'orchestrateur

- `voice-instructions.fr.md` : consigne vocale envoyée telle quelle au modèle
  (tout son contenu part au fournisseur : n'y mettre aucun commentaire).
- Cette consigne est provisoire ; son réglage est prévu en J3 et J7 (pdr-0037).
  Le modèle ne délègue que si les instructions l'exigent ([rt-gpt-live-delegation]) : elles listent
  donc les sujets à déléguer (release, qualité, crashs, avis, go/no-go), interdisent de citer un chiffre
  avant le commentaire de l'orchestrateur et demandent de le reprendre fidèlement.
- Consigne de silence (016, pdr-0082 D1) : une ligne fondée sur la forme (rien d'intelligible adressé à
  l'assistant : bruit, voix lointaine, bribe) demande de ne pas répondre, avec l'exception explicite
  « une demande d'affichage, même hors sujet, reste déléguée ». Les tests G-01 et G-02 prouvent que le texte
  est livré, pas que le modèle se tait (Q-89 : à observer en réel).
- Reprise après chevauchement : `VOICE_RECOVERY_WINDOW` (compose `8s`, code `0` = coupée) ; la phrase dite est
  `no_request` de `phrases.fr.json`.
