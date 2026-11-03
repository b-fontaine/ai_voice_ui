# language: fr
# id: p-fn-feature-design-system-019
# Scénarios complémentaires de 019 (fidélité au design system : structure des composants, échelle de texte, animations) : V-01 à V-05, composants de données : échelle de texte, KeyIndicator, TrendChart, ReleaseChecklist, ReviewSentiment. Hors des 9 de la fiche (pdr-0049). Les trois fichiers design-system-019*.feature reprennent l'unique fichier d'acceptation (découpé pour la limite de taille d'un document).
# Décisions : pdr-0087 (tailles du design system, plus de minimum de 24 px, NFR-05 suspendue), pdr-0088 (détails d'interface tranchés par la boucle, pdr-0062) ; exigences FR-04, FR-06, NFR-04, NFR-05, RG-09, RG-29.
# V-01 remplace U-01 de 017 (aucun texte sous 24 px). Rouges au départ : V-01 à V-05 (taille hors échelle, clé de widget introuvable).
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
