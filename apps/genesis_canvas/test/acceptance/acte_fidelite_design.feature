# language: fr
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

  @V-01 @NFR-05 @RG-09
  Scénario: V-01 Chaque style de texte a la taille du design system et aucun texte visible n'est hors de l'échelle, aux actes 1, 2 et 3
    Étant donné le tableau de la release 3.4 est affiché
    Alors le style {'kpi-xl'} de la scène est en {'JetBrains Mono'} de {76} px sur {76} px d'interligne, graisse {600}
    Et le style {'verdict'} de la scène est en {'JetBrains Mono'} de {28} px sur {32} px d'interligne, graisse {700}
    Et le style {'data'} de la scène est en {'JetBrains Mono'} de {15} px sur {20} px d'interligne, graisse {500}
    Et le style {'label'} de la scène est en {'JetBrains Mono'} de {11} px sur {14} px d'interligne, graisse {500}
    Et le style {'title'} de la scène est en {'Space Grotesk'} de {18} px sur {24} px d'interligne, graisse {600}
    Et le style {'transcript'} de la scène est en {'Space Grotesk'} de {20} px sur {28} px d'interligne, graisse {500}
    Et le style {'body'} de la scène est en {'Space Grotesk'} de {15} px sur {22} px d'interligne, graisse {400}
    Et le style {'button'} de la scène est en {'Space Grotesk'} de {15} px sur {20} px d'interligne, graisse {600}
    Et le style {'label'} de la scène a un interlettrage de {'0.14'} em
    Et tout texte visible de l'écran est dans l'échelle de texte du design system
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors tout texte visible de l'écran est dans l'échelle de texte du design system
    Quand la barre d'actions est jouée en direct
    Alors tout texte visible de l'écran est dans l'échelle de texte du design system
    Et aucune erreur n'est signalée

  @V-02 @FR-06 @RG-10
  Scénario: V-02 Le KeyIndicator a un chiffre de 76 px, une jauge avec seuil et repère, des deltas alignés, et rien d'inventé
    Étant donné le tableau de la release 3.4 est affiché
    Quand {2000} millisecondes s'écoulent
    Alors le texte de l'élément {'kpi-value'} est {'99,57 %'}
    Et le texte de l'élément {'kpi-value'} fait {76} px
    Et la largeur de l'élément {'kpi-gauge-fill'} fait {57} % de celle de l'élément {'kpi-gauge'} à {2} points près
    Et le centre de l'élément {'kpi-gauge-mark'} est à {50} % de la largeur de l'élément {'kpi-gauge'} à {2} points près
    Et le texte de l'élément {'kpi-gauge-mark-label'} contient {'99,50'}
    Et l'élément {'kpi-gauge-fill'} est de couleur {'warn'}
    Et l'élément {'kpi-gauge-ref'} n'est pas affiché
    Et le texte de l'élément {'kpi-delta-trend-label'} est {'Tendance'}
    Et le texte de l'élément {'kpi-delta-trend-value'} est {'−0,36 pt'}
    Et l'élément {'kpi-delta-comparison-label'} n'est pas affiché
    Et aucun texte de la surface {'kpi'} ne contient {'vs seuil'}
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et {2000} millisecondes s'écoulent
    Alors la largeur de l'élément {'kpi-gauge-fill'} fait {43} % de celle de l'élément {'kpi-gauge'} à {2} points près
    Et le centre de l'élément {'kpi-gauge-mark'} est à {50} % de la largeur de l'élément {'kpi-gauge'} à {2} points près
    Et le centre de l'élément {'kpi-gauge-ref'} est à {71} % de la largeur de l'élément {'kpi-gauge'} à {2} points près
    Et le texte de l'élément {'kpi-gauge-ref-label'} contient {'3.3'}
    Et l'élément {'kpi-gauge-fill'} est de couleur {'nogo'}
    Et le texte de l'élément {'kpi-delta-trend-label'} est {'Tendance'}
    Et le texte de l'élément {'kpi-delta-trend-value'} est {'−0,54 pt'}
    Et le texte de l'élément {'kpi-delta-comparison-label'} est {'vs 3.3'}
    Et le texte de l'élément {'kpi-delta-comparison-value'} contient {'−0,28 pt'}
    Et le texte de l'élément {'kpi-delta-comparison-value'} contient {'99,71 %'}
    Et les éléments {'kpi-delta-trend-label'} et {'kpi-delta-comparison-label'} sont alignés à gauche
    Et les éléments {'kpi-delta-trend-value'} et {'kpi-delta-comparison-value'} sont alignés à gauche
    Et aucun texte de la surface {'kpi'} ne contient {'vs seuil'}
    Quand le serveur émet l'indicateur clé avec la valeur {'n/d'}
    Alors la surface {'kpi'} affiche {'n/d'}
    Et l'élément {'kpi-gauge'} n'est pas affiché
    Et l'élément {'kpi-gauge-mark'} n'est pas affiché
    Et l'élément {'kpi-gauge-ref'} n'est pas affiché
    Et aucune erreur n'est signalée

  @V-03 @FR-06
  Scénario: V-03 Le graphique a légende à traits, grille, axe, zone sous la série, zone de franchissement, point de tête et annotation dérivés de la série
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Quand {3000} millisecondes s'écoulent
    Alors l'élément {'trend-plot'} est affiché
    Et l'élément {'trend-grid'} est affiché
    Et l'élément {'trend-axis'} est affiché
    Et l'élément {'trend-swatch-Android 3.4'} est un trait d'au plus {4} points de haut et d'au moins {12} points de large
    Et l'élément {'trend-swatch-Android 3.3'} est un trait d'au plus {4} points de haut et d'au moins {12} points de large
    Et le texte de l'élément {'trend-threshold-legend'} contient {'0,50'}
    Et l'élément {'trend-area'} est affiché
    Et le bord gauche de l'élément {'trend-area'} est celui de l'élément {'trend-plot'} à {2} points près
    Et le bord droit de l'élément {'trend-area'} est celui de l'élément {'trend-plot'} à {2} points près
    Et l'élément {'trend-breach'} est affiché
    Et le bord gauche de l'élément {'trend-breach'} est à {50} % de la largeur de l'élément {'trend-plot'} à {2} points près
    Et le bord droit de l'élément {'trend-breach'} est celui de l'élément {'trend-plot'} à {2} points près
    Et l'élément {'trend-head'} est affiché
    Et le texte de l'élément {'trend-head-value'} est {'0,84 %'}
    Et le texte de l'élément {'trend-callout'} contient {'▲'}
    Et le texte de l'élément {'trend-callout'} contient {'dès J5'}
    Quand je dis {'Non, plutôt iOS'}
    Et {3000} millisecondes s'écoulent
    Alors la courbe ne contient que la série {'iOS 3.4'}
    Et l'élément {'trend-breach'} n'est pas affiché
    Et l'élément {'trend-callout'} n'est pas affiché
    Et aucune erreur n'est signalée

  @V-04 @FR-06 @RG-09
  Scénario: V-04 La checklist est un tableau de quatre colonnes, liseré sur les lignes bloquantes, verdict en grande puce et compteur
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Quand {3000} millisecondes s'écoulent
    Alors l'élément {'checklist-table'} est affiché
    Et le texte de l'élément {'checklist-head-0'} contient {'critère'}
    Et le texte de l'élément {'checklist-head-1'} contient {'seuil'}
    Et le texte de l'élément {'checklist-head-2'} ne contient pas {'3.4'}
    Et le texte de l'élément {'checklist-head-2'} ne contient pas {'3.3'}
    Et l'élément {'checklist-head-3'} est affiché
    Et le texte de l'élément {'checklist-head-0'} est en capitales
    Et les éléments {'checklist-head-0'} et {'checklist-cell-0-0'} sont alignés à gauche
    Et les éléments {'checklist-head-1'} et {'checklist-cell-0-1'} sont alignés à gauche
    Et les éléments {'checklist-head-2'} et {'checklist-cell-0-2'} sont alignés à gauche
    Et l'élément {'checklist-row-0'} est de couleur {'surface-200'}
    Et l'élément {'checklist-row-0'} a des coins arrondis
    Et l'élément {'checklist-row-0-edge'} fait {3} points de large
    Et l'élément {'checklist-row-0-edge'} est de couleur {'nogo'}
    Et l'élément {'checklist-row-1-edge'} est affiché
    Et l'élément {'checklist-row-2-edge'} n'est pas affiché
    Et l'élément {'checklist-verdict'} fait {40} points de haut
    Et le texte de l'élément {'checklist-verdict'} contient {'NO-GO Android'}
    Et le texte de l'élément {'checklist-count'} contient {'2 bloquants / 3'}

  @V-05 @FR-06
  Scénario: V-05 Les avis ont une barre de répartition, une légende et des verbatims en cartes
    Étant donné le tableau de la release 3.4 est affiché
    Quand {3000} millisecondes s'écoulent
    Alors l'élément {'reviews-split'} est affiché
    Et la largeur de l'élément {'reviews-split-pos'} fait {76} % de celle de l'élément {'reviews-split'} à {3} points près
    Et la largeur de l'élément {'reviews-split-neg'} fait {24} % de celle de l'élément {'reviews-split'} à {3} points près
    Et l'élément {'reviews-split-pos'} est de couleur {'go'}
    Et l'élément {'reviews-split-neg'} est de couleur {'nogo'}
    Et le texte de l'élément {'reviews-legend-pos'} contient {'76 % positifs'}
    Et le texte de l'élément {'reviews-legend-neg'} contient {'24 % négatifs'}
    Et l'élément {'reviews-card-0'} est de couleur {'surface-300'}
    Et l'élément {'reviews-card-0'} a des coins arrondis
    Et le texte de l'élément {'reviews-card-0-meta'} contient {'1★'}
    Et le texte de l'élément {'reviews-card-0-meta'} contient {'Android'}
    Et le texte de l'élément {'reviews-card-0-text'} contient {'se ferme dès que je valide'}
    Et l'élément {'reviews-card-0-meta'} est à gauche de l'élément {'reviews-card-0-text'}

  @V-06 @FR-03 @FR-05
  Scénario: V-06 Le rail a son étiquette et des tuiles ; orchestrateur, agent au travail et agent terminé ont leurs couleurs
    Étant donné une session voix démarrée
    Quand le serveur émet le plan à trois agents et leur activité au travail
    Et l'agent {'Qualité'} est affiché {'en cours'}
    Alors le texte de l'élément {'agents-rail-label'} contient {'A2A'}
    Et l'élément {'agent-tile-Orchestrateur'} a des coins arrondis
    Et la bordure de l'élément {'agent-tile-Orchestrateur'} a la teinte {'plasma'}
    Et l'élément {'agent-dot-Orchestrateur'} est de couleur {'plasma'}
    Et l'élément {'agent-dot-Orchestrateur'} a une lueur de teinte {'plasma'}
    Et la bordure de l'élément {'agent-tile-Qualité'} a la teinte {'signal'}
    Et le texte de l'élément {'agent-state-Qualité'} est de couleur {'signal'}
    Et l'élément {'agent-bar-Qualité'} est affiché
    Quand le serveur émet la fin de l'activité de l'agent Qualité
    Et l'agent {'Qualité'} est affiché {'terminé'}
    Alors l'élément {'agent-dot-Qualité'} est de couleur {'go'}
    Et le texte de l'élément {'agent-state-Qualité'} contient {'✓'}
    Et l'élément {'agent-bar-Qualité'} n'est pas affiché

  @V-07 @FR-01 @FR-02
  Scénario: V-07 La barre vocale a un orbe à anneaux, une transcription VOUS / IA, des segments d'actes et des boutons du haut
    Étant donné le tableau de la release 3.4 est affiché
    Alors l'élément {'voice-orb-core'} est affiché
    Et l'élément {'voice-orb-ring-0'} est affiché
    Et l'élément {'voice-orb-ring-1'} est affiché
    Et l'élément {'voice-orb-ring-2'} est affiché
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet une réplique de l'IA {'Le tableau est prêt'} commencée à {2000} ms
    Alors le texte de l'élément {'transcript-user-who'} est {'VOUS'}
    Et le texte de l'élément {'transcript-ai-who'} est {'IA'}
    Et l'élément {'transcript-ai-caret'} est affiché
    Et le texte de l'élément {'act-segment-1'} contient {'Créer'}
    Et le texte de l'élément {'act-segment-2'} contient {'Transformer'}
    Et le texte de l'élément {'act-segment-3'} contient {'Interagir'}
    Et l'élément {'act-segment-1'} est de couleur {'plasma-ghost'}
    Et l'élément {'mic-button-visual'} fait {34} points de haut
    Et l'élément {'mic-rec-dot'} est affiché
    Et l'élément {'silence-button-visual'} fait {34} points de haut
    Et l'élément {'reset-button-visual'} fait {34} points de haut
    Quand je clique sur l'indicateur d'acte
    Alors le texte de l'élément {'act-segment-1'} contient {'✓'}
    Et l'élément {'act-segment-2'} est de couleur {'plasma-ghost'}

  @V-08 @FR-04
  Scénario: V-08 Un cadre de génération entoure la surface en cours et disparaît quand elle est complète
    Étant donné une session voix démarrée
    Quand le serveur émet la création des quatre surfaces
    Alors un seul cadre de génération est affiché
    Et l'élément {'generation-frame-checklist'} entoure l'élément {'surface-checklist'}
    Et le texte de l'élément {'generation-frame-checklist-tag'} contient {'génère'}
    Quand le serveur émet les composants des quatre surfaces
    Et le serveur émet les données des quatre surfaces
    Et {4000} millisecondes s'écoulent
    Alors l'élément {'generation-frame-checklist'} est invisible ou absent
    Et aucune erreur n'est signalée

  @V-09 @FR-08 @RG-09
  Scénario: V-09 Les boutons et les puces de statut ont l'apparence du design system
    Étant donné le tableau de la release 3.4 est affiché
    Et je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la Barre d'actions de la fin de l'acte 2
    Quand {2000} millisecondes s'écoulent
    Alors le texte de l'élément {'actions-label'} est {'Décision'}
    Et l'élément {'action-block_release-visual'} fait {44} points de haut
    Et l'élément {'action-block_release-visual'} a un rayon de {10} points
    Et l'élément {'action-block_release-visual'} a une lueur de teinte {'nogo'}
    Et l'élément {'action-block_release-dashes'} n'est pas affiché
    Et l'élément {'action-validate_release-visual'} fait {44} points de haut
    Et l'élément {'action-validate_release-dashes'} est affiché
    Et les puces de statut font {26} points de haut et sont arrondies en pilule
    Et le mot de chaque puce de statut est en capitales

  @V-10 @FR-05 @FR-09
  Scénario: V-10 Le pied a des puces de catalogue, une barre de rejeu avec piste et vitesses, et un flux A2UI en liste mono
    Étant donné le tableau de la release 3.4 est affiché
    Et je clique sur le bouton du panneau protocole
    Alors l'élément {'shelf-KeyIndicator'} fait {30} points de haut
    Et l'élément {'shelf-KeyIndicator'} a des coins arrondis
    Et l'élément {'shelf-KeyIndicator'} est de couleur {'signal-ghost'}
    Et l'élément {'shelf-CrashList'} est de couleur {'surface-100'}
    Et l'élément {'replay-play-visual'} fait {34} points de haut
    Et l'élément {'replay-track'} fait {4} points de haut
    Et l'élément {'replay-track-fill'} est affiché
    Et l'élément {'replay-track-knob'} fait {14} points de large
    Et l'élément {'replay-speed-1-visual'} fait {26} points de haut
    Et l'élément {'replay-speed-1-visual'} est de couleur {'ink'}
    Et l'élément {'replay-direct-dot'} est affiché
    Et le texte de l'élément {'protocol-entry-0-no'} est un numéro de message de la forme {'#nn'}
    Et le texte de l'élément {'protocol-entry-0-no'} est en police {'JetBrains Mono'}
    Et le texte de l'élément {'protocol-entry-0-kind'} est de couleur {'signal'}

  @V-11 @NFR-05
  Scénario: V-11 Tout texte de moins de 24 px est à 4,5:1 au moins sur son fond réel, jamais en ink-faint ni en agentIdle
    Étant donné le tableau de la release 3.4 est affiché
    Alors tout texte visible de moins de {24} px est contrasté d'au moins {4.5} sur son fond réel
    Et aucun texte visible de moins de {24} px n'a la couleur {'ink-faint'}
    Quand je dis {'Concentre-toi sur Android et compare avec la 3.3'}
    Et le serveur émet la liste des crashs jusqu'au temps {'data'}
    Alors tout texte visible de moins de {24} px est contrasté d'au moins {4.5} sur son fond réel
    Et aucun texte visible de moins de {24} px n'a la couleur {'ink-faint'}
    Quand la barre d'actions est jouée en direct
    Alors tout texte visible de moins de {24} px est contrasté d'au moins {4.5} sur son fond réel
    Et aucun texte visible de moins de {24} px n'a la couleur {'ink-faint'}

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
