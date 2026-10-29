# language: fr
Fonctionnalité: Outillage de boucle dans l'app
  Pour que la boucle voie l'app tourner sans micro, sans réseau et sans coût,
  l'app rejoue un flux A2UI v0.9 enregistré puis écrit une capture PNG.

  Scénario: H-01 Canevas vide, orbe visible
    Étant donné l'app lancée sans scénario
    Alors le canevas est vide
    Et l'orbe est visible

  Scénario: H-02 Rejeu act1-replay et surface
    Étant donné l'app lancée avec le scénario {'act1-replay'}
    Quand le rejeu se termine
    Alors une surface affiche le texte {'Sessions sans crash'}
    Et la valeur liée au modèle de données est affichée

  Scénario: H-03 Capture PNG puis sortie 0
    Étant donné l'app lancée avec GENESIS_SNAPSHOT vers un fichier temporaire
    Quand le rejeu se termine
    Alors un PNG non vide est écrit à ce chemin
    Et l'app se ferme avec le code 0
