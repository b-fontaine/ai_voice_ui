# language: fr
# id: p-fn-feature-design-system-019-ecran
# Scénarios complémentaires de 019 (fidélité au design system : structure des composants, échelle de texte, animations) : V-06 à V-11, reste de l'écran : rail, barre vocale, cadre de génération, actions et statuts, pied, contraste. Hors des 9 de la fiche (pdr-0049). Les trois fichiers design-system-019*.feature reprennent l'unique fichier d'acceptation (découpé pour la limite de taille d'un document).
# Décisions : pdr-0087 (tailles du design system, plus de minimum de 24 px, NFR-05 suspendue), pdr-0088 (détails d'interface tranchés par la boucle, pdr-0062) ; exigences FR-04, FR-06, NFR-04, NFR-05, RG-09, RG-29.
# Rouges au départ : V-06 à V-11 (clé de widget introuvable, aucun texte sous 24 px pour mesurer le contraste, aucun cadre de génération).
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
