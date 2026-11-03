# language: fr
Fonctionnalité: Design system - habillage de la scène, polices embarquées, mouvement sobre
  L'habillage vient du design system du 2026-11-02 ; la disposition, les données et le comportement restent ceux de 013 et de la fiche.
  Recalé par la spec 019 (pdr-0087, pdr-0088) : U-01 (aucun texte sous 24 px) est remplacé par V-01 de acte_fidelite_design.feature, et le flou de l'apparition (U-05, « sans flou ») est vérifié par A-01.
  Polices réelles de la scène (Ahem ne mesure pas une troncature) et plateforme simulée Linux.
  Contexte:
    Étant donné les polices réelles de la scène sont chargées
    Et la plateforme simulée est Linux
    Et un faux backend local
    Et l'app lancée sur ce backend avec une horloge virtuelle

  After:
    Alors l'app est fermée, le faux backend arrêté et la sémantique libérée
    Et la plateforme simulée est restaurée

  @U-02 @NFR-05 @NFR-10
  Scénario: U-02 Les données sont en JetBrains Mono à chiffres tabulaires, les mots en Space Grotesk, polices embarquées
    Étant donné le tableau de la release 3.4 est affiché
    Alors les valeurs, deltas, seuils et étiquettes de l'écran sont en police {'JetBrains Mono'}
    Et les chiffres des valeurs de l'écran sont tabulaires
    Et les titres, légendes, libellés de boutons et textes courants de l'écran sont en police {'Space Grotesk'}
    Et les deux polices viennent des assets du paquet de design système et de leurs licences enregistrées
    Et aucune police n'est chargée par le réseau

  @U-03 @NFR-05 @FR-06
  Scénario: U-03 La disposition de 013 est inchangée avec les polices embarquées
    Étant donné le tableau de la release 3.4 est affiché
    Et je note les rectangles des zones de l'écran
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors le canevas affiche une grille de {3} colonnes sur {2} lignes
    Et le canevas fait {676} points de haut
    Et aucun libellé de la surface {'checklist'} n'est tronqué
    Et aucun libellé de la surface {'reviews'} n'est tronqué
    Et aucun libellé de la surface {'trend'} n'est tronqué
    Et aucun libellé de l'étagère n'est tronqué
    Et les rectangles des zones de l'écran n'ont pas bougé

  @U-04 @NFR-05 @RG-09
  Scénario: U-04 Un statut s'affiche avec son mot et sa couleur du design system, jamais la couleur seule
    Étant donné le tableau de la release 3.4 est affiché
    Alors le statut {'ok'} est affiché avec son mot, la couleur {'go'} sur un fond {'go-ghost'} et le glyphe {'✓'}
    Et le glyphe d'un statut n'est pas annoncé par la sémantique
    Et le statut {'risk'} est affiché avec son mot, la couleur {'warn'} sur un fond {'warn-ghost'} et sans glyphe
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors le statut {'blocking'} est affiché avec son mot, la couleur {'nogo'} sur un fond {'nogo-ghost'} et sans glyphe
    Et le contraste du mot de chaque statut sur son fond composé est d'au moins {4.5}

  @U-05 @FR-04 @NFR-04
  Scénario: U-05 Une surface apparaît en 480 ms avec 10 points de glissement (flou : voir A-01), et seul Bloquant bat en continu
    Étant donné le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs jusqu'au temps {'components'}
    Alors le contenu de la surface {'crashes'} est à peine visible
    Et le contenu de la surface {'crashes'} est décalé de {10} points vers le bas
    Quand {240} millisecondes s'écoulent
    Alors le contenu de la surface {'crashes'} n'est pas encore pleinement visible
    Quand {260} millisecondes s'écoulent
    Alors le contenu de la surface {'crashes'} est pleinement visible
    Et le contenu de la surface {'crashes'} n'est plus décalé
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors parmi les statuts, seul le statut {'blocking'} bat en continu
    Quand les animations du système sont désactivées
    Alors aucune animation en boucle n'est active, orbe et squelette compris

  @U-06 @FR-06 @NFR-05
  Scénario: U-06 Les séries du graphique ont les couleurs du design system, la série 3.3 est en pointillés, le seuil en tirets
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors la série {'Android 3.4'} du graphique est tracée en {'signal'} en trait plein
    Et la série {'Android 3.3'} du graphique est tracée en {'signal'} en pointillés
    Et le seuil du graphique est tracé en {'nogo'} en tirets
    Et aucune série du graphique n'est tracée avec une couleur de statut ni avec {'plasma'}
