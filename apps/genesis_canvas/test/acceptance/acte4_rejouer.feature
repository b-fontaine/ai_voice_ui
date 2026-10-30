# language: fr
Fonctionnalité: Acte 4 - rejouer la construction du tableau
  Pour montrer, sans réseau ni modèle, comment le tableau a été construit, le
  speaker lance la lecture du journal du flux A2UI dans la zone « Rejeu » :
  le canevas se vide puis se reconstruit à l'identique du direct, de 0,25× à
  2×, avec le panneau du protocole synchronisé sur le message rejoué (FR-09,
  RG-19, NFR-08 ; pdr-0066, D1 à D8). Les scénarios sont propres à la spec 010 :
  la fiche n'en décrit pas pour FR-09. Le temps est simulé : l'horloge de l'app
  est virtuelle (une surface toutes les deux secondes), le plafond d'écart est
  de 3 s, le pas du lecteur de 100 ms et la vitesse par défaut de 1×.

  Contexte:
    Étant donné un faux backend local
    Et l'app lancée sur ce backend avec une horloge virtuelle

  After:
    Alors l'app est fermée, le faux backend arrêté et la sémantique libérée

  @R-01 @FR-09 @NFR-08
  Scénario: R-01 Le rejeu est identique au direct, sans aucune requête
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et je clique sur le bouton du panneau protocole
    Et le panneau protocole affiche ses derniers messages
    Et je note le rendu affiché
    Et je note le nombre de requêtes reçues par le faux backend
    Quand je clique sur Lecture
    Alors la surface {'checklist'} n'est pas encore affichée
    Et l'indicateur d'acte affiche {'Acte 4 · Rejeu'}
    Quand je choisis la vitesse {2}
    Et j'attends la fin du rejeu
    Alors le rendu affiché est identique à celui noté
    Et le faux backend n'a reçu aucune requête depuis
    Et aucun message A2UI n'est refusé

  @R-02 @FR-09
  Scénario: R-02 La durée du rejeu est proportionnelle à 1/vitesse
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Quand je clique sur Lecture
    Et je choisis la vitesse {2}
    Et j'attends la fin du rejeu
    Et je clique sur Lecture
    Et je choisis la vitesse {0.25}
    Et j'attends la fin du rejeu
    Alors la seconde durée mesurée vaut {8} fois la première

  @R-02 @FR-09
  Scénario: R-02 Changer de vitesse en cours de lecture n'interrompt ni ne saute
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Quand je clique sur Lecture
    Et le rejeu avance de {2} secondes
    Et je note la position du curseur
    Et je choisis la vitesse {2}
    Alors la position du curseur n'a pas bougé de plus de {5} points
    Et le bouton de lecture affiche {'Pause'}
    Quand le rejeu avance de {1} secondes
    Alors la position du curseur a avancé de {33} points à {5} points près

  @R-03 @FR-09
  Scénario: R-03 Le curseur avant puis arrière laisse les surfaces et le panneau de ce point
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Quand je clique sur Lecture
    Et je clique sur Pause
    Et je place le curseur au milieu
    Alors les surfaces affichées sont {'kpi,trend'}
    Et le panneau protocole compte {6} messages
    Quand je note le rendu affiché
    Et je clique sur Lecture
    Et le rejeu avance de {2} secondes
    Alors les surfaces affichées sont {'kpi,trend,reviews'}
    Quand je clique sur Pause
    Et je place le curseur au milieu
    Alors les surfaces affichées sont {'kpi,trend'}
    Et le panneau protocole compte {6} messages
    Et le rendu affiché est identique à celui noté

  @R-03 @FR-09
  Scénario: R-03 Glisser le curseur ne déclenche qu'un seul seek, au relâchement
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Quand je clique sur Lecture
    Et le rejeu avance de {2.5} secondes
    Et je clique sur Pause
    Et je note le rendu affiché
    Et je pose le doigt au milieu du curseur
    Et je glisse le doigt vers le début du curseur
    Alors le rendu affiché est identique à celui noté
    Quand je relâche le doigt
    Alors les surfaces affichées sont {'kpi'}
    Et le panneau protocole compte {3} messages

  @R-04 @FR-09
  Scénario: R-04 Pause, reprise et fin du rejeu
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Quand je clique sur Lecture
    Et le rejeu avance de {2.5} secondes
    Et je clique sur Pause
    Et je note le rendu affiché
    Et le rejeu avance de {5} secondes
    Alors le rendu affiché est identique à celui noté
    Et le bouton de lecture affiche {'Lecture'}
    Quand je clique sur Lecture
    Et le rejeu avance de {5} secondes
    Alors le rejeu est terminé
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist'}
    Et le bouton de lecture affiche {'Lecture'}
    Quand je clique sur Lecture
    Et le rejeu avance de {0.3} secondes
    Alors le curseur est à environ {5} % à {5} points près
    Et la surface {'checklist'} n'est pas encore affichée

  @R-04 @FR-09
  Scénario: R-04 Recommencer repart du début
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Quand je clique sur Lecture
    Et le rejeu avance de {4.5} secondes
    Alors les surfaces affichées sont {'kpi,trend,reviews'}
    Quand je clique sur Recommencer
    Alors le curseur est à environ {0} % à {5} points près
    Et la surface {'reviews'} n'est pas encore affichée

  @R-05 @FR-09 @RG-19
  Scénario: R-05 Pendant le rejeu, un message vivant est écarté et la voix n'est pas touchée
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et la barre d'actions est jouée en direct
    Et les boutons de la barre d'actions sont actifs
    Quand je clique sur Lecture
    Et j'attends la fin du rejeu
    Alors les boutons de la barre d'actions sont inactifs
    Et le panneau protocole compte {15} messages
    Quand le serveur émet un message A2UI vivant
    Alors le panneau protocole compte {15} messages
    Et les surfaces affichées sont {'kpi,trend,reviews,checklist,actions'}
    Et une session voix est active
    Et un seul transport a été créé
    Et le relais n'a reçu aucun DELETE

  @R-05 @FR-09 @RG-19
  Scénario: R-05 Pendant le rejeu, le bouton Démarrer est inactif
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et je clique sur Arrêter
    Et le bouton Démarrer est affiché
    Quand je clique sur Lecture
    Alors le bouton Démarrer est inactif

  @R-06 @FR-09
  Scénario: R-06 Direct vide tout, demande la remise à vide et vide le journal
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et je clique sur Lecture
    Et le rejeu avance de {2.5} secondes
    Quand je clique sur Direct
    Alors aucune surface n'est affichée
    Et le panneau protocole est vide
    Et l'étagère affiche {'0 / 6 utilisés'}
    Et le faux backend a reçu exactement une requête de remise à vide
    Et l'indicateur d'acte n'affiche plus {'Rejeu'}
    Et le bouton Lecture est inactif

  @R-07 @FR-09
  Scénario: R-07 Sans message enregistré, Lecture est inactif
    Étant donné une session voix démarrée
    Alors le bouton Lecture est inactif

  @R-07 @FR-09
  Scénario: R-07 Pendant qu'un agent travaille, Lecture est inactif
    Étant donné une session voix démarrée
    Et le serveur émet le plan à trois agents et leur activité au travail
    Et le serveur émet la surface {'kpi'} en trois temps
    Alors le bouton Lecture est inactif
    Quand le serveur émet la fin de l'activité des trois agents
    Alors le bouton Lecture est actif

  @R-08 @FR-09
  Scénario: R-08 Un long silence est plafonné et le curseur couvre la durée comprimée
    Étant donné une session voix démarrée
    Et le serveur émet la surface {'kpi'} en trois temps
    Et {60} secondes s'écoulent sur l'horloge de l'app
    Et le serveur émet la surface {'trend'} en trois temps
    Et le serveur émet la fin de l'activité des trois agents
    Quand je clique sur Lecture
    Et le rejeu avance de {1.5} secondes
    Alors le curseur est à environ {50} % à {6} points près
    Et le rejeu n'est pas terminé
    Quand le rejeu avance de {2} secondes
    Alors le rejeu est terminé

  @R-09 @FR-09
  Scénario: R-09 Remettre à vide pendant le rejeu équivaut à Direct
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et je clique sur Lecture
    Et le rejeu avance de {2.5} secondes
    Quand je clique sur Remettre à vide
    Alors aucune surface n'est affichée
    Et le faux backend a reçu exactement une requête de remise à vide
    Et l'indicateur d'acte n'affiche plus {'Rejeu'}
    Et le bouton Lecture est inactif
    Et aucun message A2UI n'est refusé

  @FR-09
  Scénario: Démonter la page pendant une lecture ne laisse aucun minuteur actif
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et je clique sur Lecture
    Et le rejeu avance de {1} secondes
    Quand la page est démontée pendant la lecture
    Alors aucun minuteur n'est resté actif
