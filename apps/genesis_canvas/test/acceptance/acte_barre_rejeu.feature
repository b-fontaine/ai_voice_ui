# language: fr
Fonctionnalité: Barre de rejeu toujours atteignable, panneau du protocole replié ou déplié
  Le speaker pilote le rejeu de l'acte 4 (Lecture, Recommencer, glissière, « Direct », cinq vitesses) que le panneau du protocole soit replié ou déplié, à 1920×1080. Une commande est atteignable quand le clic l'atteint (elle n'est recouverte par rien) et que son rectangle ne recoupe pas celui du panneau ; la glissière doit l'être aussi à son extrémité droite, car elle ne positionne qu'au relâchement. Déplié, le panneau quitte la rangée du bas : il ne la recouvre pas, ne recouvre pas le rail et laisse passer les clics hors de son rectangle.
  Contexte:
    Étant donné un faux backend local
    Et l'app lancée sur ce backend avec une horloge virtuelle

  After:
    Alors l'app est fermée, le faux backend arrêté et la sémantique libérée

  @RB-01 @FR-09 @FR-05
  Scénario: RB-01 Panneau déplié, chaque commande de la barre de rejeu est atteignable
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et le rejeu est en pause à mi-parcours
    Quand je clique sur le bouton du panneau protocole
    Alors chaque commande de la barre de rejeu est atteignable
    Et l'extrémité droite de la glissière est atteignable

  @RB-02 @FR-09 @FR-05
  Scénario: RB-02 Panneau replié, chaque commande de la barre de rejeu est atteignable
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et le rejeu est en pause à mi-parcours
    Alors chaque commande de la barre de rejeu est atteignable
    Et l'extrémité droite de la glissière est atteignable

  @RB-03 @FR-09 @FR-05
  Scénario: RB-03 Panneau déplié, la rangée du bas et le rail restent libres et les clics hors du panneau le traversent
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Et la barre d'actions est jouée en direct
    Quand je clique sur le bouton du panneau protocole
    Alors le panneau protocole déplié ne recouvre ni la rangée du bas ni le rail
    Et les entrées du panneau et son bouton Replier sont visibles dans la fenêtre
    Et le panneau protocole déplié montre {4} entrées
    Et les commandes hors du panneau restent atteignables
    Quand je clique sur Lecture
    Et je choisis la vitesse {2}
    Et j'attends la fin du rejeu
    Alors aucun message A2UI n'est refusé
