# Configuration de l'orchestrateur

- `voice-instructions.fr.md` : consigne vocale envoyée telle quelle au modèle
  (tout son contenu part au fournisseur : n'y mettre aucun commentaire).
- Cette consigne est provisoire ; son réglage est prévu en J3 et J7 (pdr-0037).
  Le modèle ne délègue que si les instructions l'exigent ([rt-gpt-live-delegation]) : elles listent
  donc les sujets à déléguer (release, qualité, crashs, avis, go/no-go), interdisent de citer un chiffre
  avant le commentaire de l'orchestrateur et demandent de le reprendre fidèlement.
