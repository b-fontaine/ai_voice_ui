# language: fr
# id: p-fn-feature-design-system-019-mouvement
# Scénarios complémentaires de 019 (fidélité au design system : structure des composants, échelle de texte, animations) : A-01 à A-07 et I-01, mouvement (horloge simulée) et indicateur d'acte. Hors des 9 de la fiche (pdr-0049). Les trois fichiers design-system-019*.feature reprennent l'unique fichier d'acceptation (découpé pour la limite de taille d'un document).
# Décisions : pdr-0087 (tailles du design system, plus de minimum de 24 px, NFR-05 suspendue), pdr-0088 (détails d'interface tranchés par la boucle, pdr-0062) ; exigences FR-04, FR-06, NFR-04, NFR-05, RG-09, RG-29.
# A-01 reprend le flou d'apparition qu'excluait U-05 de 017. État final (019 livrée, miroir de l'acceptation, tous verts) : A-01 depuis T12, A-02 depuis T22, A-03 depuis T21, A-04 depuis T23, A-05 depuis T32, A-06 depuis T33, A-07 depuis T22 (reverifié en T34) ; les trois scénarios I-01 verrouillent l'indicateur d'acte (effet attendu du mode scénario, confirmé par T40).
# Les parties d'un composant sont cherchées par clés de widgets `<surface>-<partie>` (contrat dans apps/genesis_canvas/test/acceptance/support/keys.dart) ; les animations se prouvent à l'horloge simulée du banc de test, jamais par capture.
# Automatisé en Flutter : apps/genesis_canvas/test/acceptance/acte_fidelite_design.feature.
# Steps sans chiffre initial (pdr-0022-gherkin-steps-no-leading-digit).

Fonctionnalité: Fidélité au design system - structure des composants, échelle de texte, animations
  Spec 019 (pdr-0087, pdr-0088). Chaque composant reprend la structure visuelle de son preview.html du design système du 2026-11-02, aux tailles du design système (plus de minimum de 24 px) et avec ses animations ; l'UX, les données, le contrat A2UI, la grille de page et les rectangles de cellules ne bougent pas.
  Les structures sont cherchées par clés de widgets de la forme <surface>-<partie> (voir support/keys.dart). Les animations se prouvent à l'horloge simulée du banc de test, jamais par capture.
  Polices réelles de la scène (Ahem ne mesure pas une troncature) et plateforme simulée Linux.
  Contexte:
    Étant donné les polices réelles de la scène sont chargées
    Et la plateforme simulée est Linux
    Et un faux backend local
    Et l'app lancée sur ce backend avec une horloge virtuelle

  After:
    Alors l'app est fermée, le faux backend arrêté et la sémantique libérée
    Et la plateforme simulée est restaurée

  @A-01 @FR-04 @NFR-04
  Scénario: A-01 Une surface apparaît en 480 ms, de flou et de 10 points vers le net ; immédiate sous disableAnimations
    Étant donné le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs jusqu'au temps {'components'}
    Alors le contenu de la surface {'crashes'} est à peine visible
    Et le contenu de la surface {'crashes'} est décalé de {10} points vers le bas
    Et le contenu de la surface {'crashes'} est flou
    Et le contenu de la surface {'crashes'} est légèrement réduit
    Quand {240} millisecondes s'écoulent
    Alors le contenu de la surface {'crashes'} n'est pas encore pleinement visible
    Et le contenu de la surface {'crashes'} n'est pas encore net
    Quand {260} millisecondes s'écoulent
    Alors le contenu de la surface {'crashes'} est pleinement visible
    Et le contenu de la surface {'crashes'} n'est plus décalé
    Et le contenu de la surface {'crashes'} est net et à l'échelle
    Quand les animations du système sont désactivées
    Et la barre d'actions est jouée en direct
    Alors le contenu de la surface {'actions'} est pleinement visible
    Et le contenu de la surface {'actions'} n'est plus décalé
    Et le contenu de la surface {'actions'} est net et à l'échelle

  @A-02 @FR-04
  Scénario: A-02 Les lignes de la checklist apparaissent l'une après l'autre, à 180 ms d'écart
    Étant donné une session voix démarrée
    Quand le serveur émet la surface {'checklist'} en trois temps
    Et {100} millisecondes s'écoulent
    Alors la ligne {0} de la checklist est apparue en partie
    Et la ligne {1} de la checklist n'a pas commencé
    Et la ligne {2} de la checklist n'a pas commencé
    Quand {100} millisecondes s'écoulent
    Alors la ligne {1} de la checklist est apparue en partie
    Et la ligne {2} de la checklist n'a pas commencé
    Quand {200} millisecondes s'écoulent
    Alors la ligne {2} de la checklist est apparue en partie
    Quand {1000} millisecondes s'écoulent
    Alors toutes les lignes de la checklist sont pleinement visibles

  @A-03 @FR-06
  Scénario: A-03 Le graphique se dévoile de gauche à droite, puis le point de tête apparaît
    Étant donné une session voix démarrée
    Quand le serveur émet la surface {'trend'} en trois temps
    Et {250} millisecondes s'écoulent
    Alors la fraction visible de l'élément {'trend-reveal'} est comprise entre {5} et {95} %
    Et l'élément {'trend-head'} est invisible
    Quand {2500} millisecondes s'écoulent
    Alors la fraction visible de l'élément {'trend-reveal'} est de {100} %
    Et l'élément {'trend-head'} est pleinement visible

  @A-04 @FR-06
  Scénario: A-04 Le KPI descend de 100 % à sa valeur en 1,4 s ; la jauge et la barre de répartition se remplissent
    Étant donné une session voix démarrée
    Quand le serveur émet la surface {'kpi'} en trois temps
    Et le serveur émet la surface {'reviews'} en trois temps
    Et {100} millisecondes s'écoulent
    Alors le nombre affiché par l'élément {'kpi-value'} est compris entre {99.58} et {100}
    Et la largeur de l'élément {'kpi-gauge-fill'} fait moins de {40} % de celle de l'élément {'kpi-gauge'}
    Et la largeur de l'élément {'reviews-split-pos'} fait moins de {50} % de celle de l'élément {'reviews-split'}
    Quand je note le nombre affiché par l'élément {'kpi-value'}
    Et {400} millisecondes s'écoulent
    Alors le nombre affiché par l'élément {'kpi-value'} est inférieur au nombre noté
    Quand {1500} millisecondes s'écoulent
    Alors le texte de l'élément {'kpi-value'} est {'99,57 %'}
    Et la largeur de l'élément {'kpi-gauge-fill'} fait {57} % de celle de l'élément {'kpi-gauge'} à {2} points près
    Et la largeur de l'élément {'reviews-split-pos'} fait {76} % de celle de l'élément {'reviews-split'} à {3} points près

  @A-05 @FR-04
  Scénario: A-05 Le cadre de génération tourne pendant la génération, fait un dernier tour puis s'estompe
    Étant donné une session voix démarrée
    Quand le serveur émet la liste des crashs jusqu'au temps {'components'}
    Alors l'élément {'generation-frame-crashes'} est animé
    Quand le serveur émet la liste des crashs jusqu'au temps {'data'}
    Et {1000} millisecondes s'écoulent
    Alors l'élément {'generation-frame-crashes'} est animé
    Quand {2100} millisecondes s'écoulent
    Alors l'élément {'generation-frame-crashes'} est en train de s'estomper
    Quand {800} millisecondes s'écoulent
    Alors l'élément {'generation-frame-crashes'} est invisible ou absent

  @A-06 @FR-01 @FR-04
  Scénario: A-06 Onde et anneaux seulement quand l'IA parle ; seul Bloquant bat ; une nouvelle puce du catalogue s'illumine
    Étant donné le tableau de la release 3.4 est affiché
    Alors l'élément {'voice-wave'} n'est pas animé
    Et l'élément {'voice-orb-ring-0'} n'est pas animé
    Quand le serveur émet un niveau d'orbe de {'0.1'}
    Alors l'élément {'voice-wave'} est animé
    Et l'élément {'voice-orb-ring-0'} est animé
    Quand le serveur émet un niveau d'orbe de {'0'}
    Et le niveau lissé de l'orbe retombe à zéro
    Alors l'élément {'voice-wave'} n'est pas animé
    Et l'élément {'voice-orb-ring-0'} n'est pas animé
    Quand la barre d'actions est jouée en direct
    Alors l'élément {'shelf-ActionBar'} a une lueur de teinte {'signal'}
    Quand {2000} millisecondes s'écoulent
    Alors l'élément {'shelf-ActionBar'} n'a pas de lueur
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors parmi les statuts, seul le statut {'blocking'} bat en continu

  @A-07 @NFR-04
  Scénario: A-07 Mouvement réduit : en rejeu de scénario aux actes 1 à 3, aucune animation ne tourne et l'état final est affiché
    Étant donné l'app est relancée en rejeu {'act1-replay'} sur ce backend
    Quand le rejeu se termine
    Alors aucune animation en boucle n'est active, orbe et squelette compris
    Et l'élément {'kpi-gauge'} est affiché
    Et l'élément {'trend-head'} est pleinement visible
    Et l'élément {'checklist-row-2'} est pleinement visible
    Quand l'app est relancée en rejeu {'act2-replay'} sur ce backend
    Et le rejeu se termine
    Alors aucune animation en boucle n'est active, orbe et squelette compris
    Et le texte de l'élément {'kpi-value'} est {'99,43 %'}
    Et la largeur de l'élément {'kpi-gauge-fill'} fait {43} % de celle de l'élément {'kpi-gauge'} à {2} points près
    Quand l'app est relancée en rejeu {'act3-replay'} sur ce backend
    Et le rejeu se termine
    Alors aucune animation en boucle n'est active, orbe et squelette compris
    Et le texte de l'élément {'kpi-value'} est {'99,43 %'}
    Et l'élément {'checklist-row-0-edge'} est affiché

  @A-07 @NFR-04
  Scénario: A-07 Mouvement réduit : sous disableAnimations, aux actes 1 à 3, aucune animation ne tourne et l'état final est affiché d'emblée
    Étant donné les animations du système sont désactivées
    Et le tableau de la release 3.4 est affiché
    Et je clique sur le bouton du panneau protocole
    Alors aucune animation en boucle n'est active, orbe et squelette compris
    Et l'élément {'kpi-gauge'} est affiché
    Et l'élément {'trend-head'} est pleinement visible
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors aucune animation en boucle n'est active, orbe et squelette compris
    Et le texte de l'élément {'kpi-value'} est {'99,43 %'}
    Et la largeur de l'élément {'kpi-gauge-fill'} fait {43} % de celle de l'élément {'kpi-gauge'} à {2} points près
    Quand la barre d'actions est jouée en direct
    Alors aucune animation en boucle n'est active, orbe et squelette compris
    Et le contenu de la surface {'actions'} est net et à l'échelle

  @I-01 @FR-09
  Scénario: I-01 En mode scénario, l'indicateur d'acte reste à l'état initial « Acte 1/3 · Créer »
    Étant donné l'app est relancée en rejeu {'act3-replay'} sur ce backend
    Quand le rejeu se termine
    Alors l'indicateur d'acte affiche {'Acte 1/3 · Créer'}
    Et aucune erreur n'est signalée

  @I-01 @FR-09
  Scénario: I-01 En rejeu réel, l'indicateur d'acte affiche « Acte 4 · Rejeu »
    Étant donné le tableau de la release 3.4 est joué en direct, une surface toutes les {2} secondes
    Quand je clique sur Lecture
    Alors l'indicateur d'acte affiche {'Acte 4 · Rejeu'}
    Quand je choisis la vitesse {2}
    Et j'attends la fin du rejeu
    Et aucune erreur n'est signalée

  @I-01 @FR-09
  Scénario: I-01 En vivant, l'indicateur d'acte avance jusqu'à l'acte 3
    Étant donné le tableau de la release 3.4 est affiché
    Alors l'indicateur d'acte affiche {'Acte 1/3'}
    Quand la barre d'actions est jouée en direct
    Alors l'indicateur d'acte affiche {'Acte 2/3'}
    Quand je clique sur le bouton {'block_release'}
    Alors l'indicateur d'acte affiche {'Acte 3/3'}
