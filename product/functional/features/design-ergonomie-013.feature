# language: fr
# id: p-fn-feature-design-ergonomics-013
# Scénarios complémentaires de 013 (livrée le 2026-10-31), hors des 9 de la fiche (pdr-0049) ; D-01 à D-07 ne sont pas les critères D1 à D8 de la DoD.
# Décisions : pdr-0072, pdr-0075, pdr-0062 ; exigences FR-04, NFR-04, NFR-05, S-02 ; steps sans chiffre initial (pdr-0022-gherkin-steps-no-leading-digit).
# Automatisé en Flutter : apps/genesis_canvas/test/acceptance/acte_design_ergonomie.feature ; unitaires : features/canvas (reconstruction, peinture), shared/design_system (tokens, mouvement).

Fonctionnalité: Design et ergonomie - écran lisible, régie à portée de main, apparition animée
  Rail de 96 px, canevas de 676 px à 1920×1080 (2 × 302 + bandeau de 72 px), cellules sans libellé tronqué, régie en deux contrôles de 48 px,
  surfaces qui apparaissent en trois temps sans rien déplacer. Polices réelles (Ahem ne mesure pas une troncature) et plateforme simulée Linux.
  Contexte:
    Étant donné les polices réelles de la scène sont chargées
    Et la plateforme simulée est Linux
    Et un faux backend local
    Et l'app lancée sur ce backend avec une horloge virtuelle

  @D-01 @FR-01 @NFR-05
  Scénario: D-01 Aucune bande vide entre le rail et le canevas, en direct puis en rejeu
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Alors le canevas commence {8} points sous le rail des agents
    Et le canevas fait {676} points de haut
    Et la première surface est au ras du haut du canevas
    Quand je clique sur Lecture
    Et j'attends la fin du rejeu
    Alors le canevas commence {8} points sous le rail des agents
    Et le canevas fait {676} points de haut
    Et la première surface est au ras du haut du canevas

  # Mesuré (cellule 624×302, données de l'acte 2) : 2 critères puis « + 1 autres critères », 1 extrait puis « + 2 avis » ; à juger par le porteur (Q-83 → pdr-0075 D2).
  @D-02 @FR-06 @NFR-05
  Scénario: D-02 La checklist et les avis de l'acte 2 ne sont tronqués nulle part en 3 x 2
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors le canevas affiche une grille de {3} colonnes sur {2} lignes
    Et aucun libellé de la surface {'checklist'} n'est tronqué
    Et aucun libellé de la surface {'reviews'} n'est tronqué
    Et la surface {'reviews'} affiche entre {1} et {2} extraits d'avis entiers et l'indication « + N avis » pour les autres
    Et le texte de la surface {'checklist'} fait au moins {24} px
    Et le texte de la surface {'reviews'} fait au moins {24} px
    Et aucune erreur n'est signalée

  @D-03 @FR-06 @NFR-05
  Scénario: D-03 Le titre de la courbe est entier et la légende passe sous le titre
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors le canevas affiche une grille de {3} colonnes sur {2} lignes
    Et le titre de la courbe n'est pas tronqué
    Et la légende de la courbe est sous son titre
    Et aucun libellé de la surface {'trend'} n'est tronqué
    Et aucune erreur n'est signalée

  @D-04 @FR-06 @NFR-05
  Scénario: D-04 L'étagère affiche six noms entiers et porte l'état par une icône et la sémantique
    Étant donné le tableau de la release 3.4 est affiché
    Alors l'étagère affiche {'4 / 6 utilisés'}
    Et l'étagère affiche {6} noms de composants entiers
    Et aucun libellé de l'étagère n'est tronqué
    Et le composant {'KeyIndicator'} de l'étagère porte une icône d'état et est annoncé {'utilisé'}
    Et le composant {'ReleaseChecklist'} de l'étagère porte une icône d'état et est annoncé {'utilisé'}
    Et le composant {'ActionBar'} de l'étagère porte une icône d'état et est annoncé {'inutilisé'}
    Et le composant {'CrashList'} de l'étagère porte une icône d'état et est annoncé {'inutilisé'}
    Et l'icône d'état d'un composant utilisé diffère de celle d'un composant inutilisé

  @D-05 @FR-11 @NFR-05
  Scénario: D-05 La régie empile deux contrôles de 48 points et le panneau déplié reste dans sa zone
    Étant donné le tableau de la release 3.4 est affiché
    Alors l'indicateur d'acte est empilé au-dessus du bouton Remettre à vide
    Et l'indicateur d'acte fait au moins {48} points dans les deux sens
    Et le bouton Remettre à vide fait au moins {48} points dans les deux sens
    Quand le serveur émet la fixture refusée {'component_not_allowed'}
    Et la barre d'actions est jouée en direct
    Et je clique sur le bouton du panneau protocole
    Alors le panneau protocole est déplié
    Et le panneau protocole affiche un message {'refusé'}
    Et le panneau protocole déplié ne dépasse pas le haut du canevas
    Et aucune erreur n'est signalée

  @D-06 @FR-04 @NFR-04
  Scénario: D-06 Une surface apparaît en trois temps : squelette, composants, données
    Étant donné le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs jusqu'au temps {'skeleton'}
    Alors un squelette est visible pour la surface {'crashes'}
    Quand le serveur émet la liste des crashs jusqu'au temps {'components'}
    Alors le contenu de la surface {'crashes'} est à peine visible
    Quand {250} millisecondes s'écoulent
    Alors le contenu de la surface {'crashes'} est pleinement visible
    Et aucun squelette n'est visible pour la surface {'crashes'}
    Quand le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors la ligne {1} de la liste des crashs est à peine visible
    Quand {200} millisecondes s'écoulent
    Alors la ligne {1} de la liste des crashs est pleinement visible
    Et aucune erreur n'est signalée

  @D-06 @FR-04 @NFR-04
  Scénario: D-06 Avec les animations du système désactivées, le résultat est immédiat
    Étant donné le tableau de la release 3.4 est affiché
    Et les animations du système sont désactivées
    Quand le serveur émet la liste des crashs jusqu'au temps {'components'}
    Alors le contenu de la surface {'crashes'} est pleinement visible
    Quand le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors la ligne {1} de la liste des crashs est pleinement visible
    Et aucune erreur n'est signalée

  @D-06 @FR-04 @FR-09 @NFR-04
  Scénario: D-06 En rejeu à 2 x la durée de l'apparition est divisée par deux
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Quand je clique sur Lecture
    Et je choisis la vitesse {2}
    Et j'avance par pas de {10} millisecondes jusqu'à ce que les composants de la surface {'checklist'} soient affichés
    Alors le contenu de la surface {'checklist'} est à peine visible
    Quand {120} millisecondes s'écoulent
    Alors le contenu de la surface {'checklist'} est pleinement visible

  @D-07 @FR-03 @NFR-04
  Scénario: D-07 L'arrivée du premier plan ne déplace aucune zone
    Étant donné une session voix démarrée
    Et je note les rectangles des zones de l'écran
    Quand le serveur émet le plan à trois agents et leur activité au travail
    Alors les rectangles des zones de l'écran n'ont pas bougé

  @D-07 @S-02 @NFR-04
  Scénario: D-07 Une mutation de l'acte 2 ne déplace ni zone ni surface
    Étant donné le tableau de la release 3.4 est affiché
    Et je note les rectangles des zones de l'écran
    Et je note les rectangles des surfaces
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Alors les rectangles des zones de l'écran n'ont pas bougé
    Et les rectangles des surfaces n'ont pas bougé
    Et les surfaces existantes restent à leur place

  @D-07 @S-02 @NFR-04
  Scénario: D-07 L'arrivée du bandeau d'actions ne déplace ni zone ni surface
    Étant donné le tableau de la release 3.4 est affiché
    Et je note les rectangles des zones de l'écran
    Et je note les rectangles des surfaces
    Quand la barre d'actions est jouée en direct
    Alors les rectangles des zones de l'écran n'ont pas bougé
    Et les rectangles des surfaces n'ont pas bougé
    Et les surfaces existantes restent à leur place

  @D-07 @S-02 @NFR-04
  Scénario: D-07 L'arrivée d'une surface de la grille ne recrée aucun State et ne déplace aucune surface en cours d'image
    Étant donné le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs jusqu'au temps {'skeleton'}
    Et je note les rectangles des surfaces
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors les rectangles des surfaces restent constants à chaque image pendant {400} millisecondes
    Et les surfaces de l'acte 1 gardent leur State
    Et aucune erreur n'est signalée
