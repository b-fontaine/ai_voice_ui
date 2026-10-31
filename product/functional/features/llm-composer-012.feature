# language: fr
# id: p-fn-feature-llm-composer-012
# Scénarios complémentaires de 012 (livrée le 2026-10-31), hors des 9 scénarios de la fiche (DoD : S-01 à S-09, pdr-0049).
# Décisions : pdr-0070, pdr-0060, pdr-0023, pdr-0074 (D1 à D11). Règles : RG-02, RG-07 à RG-10, RG-24.
# Automatisation : Go (tag acceptance) = backend/agents/acceptance/composer_llm_test.go (C-01 à C-06), backend/orchestrator/acceptance/
#    llm_gateway_test.go (C-07), crashlist_e2e_test.go (C-08) ; Flutter = apps/genesis_canvas/test/acceptance/acte_crashlist.feature (F-01, F-02).
# Steps sans chiffre initial (pdr-0022-gherkin-steps-no-leading-digit).

Fonctionnalité: Composition de l'écran par un modèle, repli sans modèle et liste des crashs

  # Automatisé (Go) : TestC01_ValidPlanEqualsDeterministic
  @C-01 @FR-04 @NFR-08 @RG-24
  Scénario: C-01 Un plan valide du modèle donne les mêmes surfaces et valeurs que sans modèle
    Soit le modèle propose les indicateurs clés et la courbe de tendance
    Quand je dis "Prépare la release 3.4"
    Alors le modèle n'est interrogé qu'une fois
    Et les surfaces, leurs données et le résumé sont identiques à ceux de la composition sans modèle

  # Automatisé (Go) : TestC02_InvalidPlanFallsBackWithSingleCall (six plans), TestC03_SlowOrFailingGatewayFallsBackInTime
  #    (délai, erreur 500, plafond de débit 429), TestC06_UnknownRefusalReasonFallsBack (motif de refus inconnu)
  @C-02 @C-03 @C-06 @FR-04 @NFR-02 @NFR-03 @NFR-08 @RG-07
  Plan du Scénario: C-02 Un modèle en panne ou un plan invalide retombe sur la composition sans modèle
    Soit le modèle "<défaut>"
    Quand je dis "Prépare la release 3.4"
    Alors le résultat est celui de la composition sans modèle
    Et il est obtenu avant la fin du délai de composition, marge comprise
    Et le modèle n'est interrogé qu'une fois
    Et le motif du repli est journalisé dans un ensemble fermé

    Exemples:
      | défaut                                               |
      | propose un composant hors du profil de l'agent       |
      | propose la barre d'actions                           |
      | propose un paramètre hors de la liste fermée         |
      | propose une plateforme contradictoire avec la demande |
      | répond un JSON cassé                                 |
      | propose un plan vide                                 |
      | refuse pour un motif inconnu                         |
      | répond plus lentement que le délai prévu             |
      | répond par une erreur côté serveur                   |
      | est bridé par le plafond de débit                    |

  # Automatisé (Go) : TestC04_CrashListFromPlan (globale, Android, iOS)
  @C-04 @FR-04 @NFR-08 @RG-24
  Plan du Scénario: C-04 La liste des crashs vient du jeu de données, filtrée si une plateforme est nommée
    Soit le modèle propose la liste des crashs
    Quand je dis "<demande>"
    Alors la surface "crashes" est construite en trois temps : création, composants, données
    Et le titre est "<titre>"
    Et les lignes sont les principaux crashs du jeu de données, rangs renumérotés de 1 à n

    Exemples:
      | demande                                 | titre                       |
      | Affiche la liste des crashs             | Principaux crashs · 3.4     |
      | Affiche la liste des crashs sur Android | Principaux crashs · Android |
      | Affiche la liste des crashs sur iOS     | Principaux crashs · iOS     |

  # Automatisé (Go) : TestC05_CrashListWithoutGateway (adresse absente, passerelle morte)
  @C-05 @NFR-08 @RG-24
  Scénario: C-05 Sans modèle, la même demande donne la même liste des crashs
    Soit le modèle n'est pas joignable
    Quand je dis "Affiche la liste des crashs"
    Alors la surface "crashes" porte les mêmes données que lorsque le modèle répond

  # Automatisé (Go) : TestC06_UnknownViewRejected_Fallback (sans modèle) et _ModelRefusal (refus du modèle, sans repli)
  @C-06 @RG-07 @RG-08
  Plan du Scénario: C-06 Une vue que le catalogue ne sait pas produire est refusée honnêtement
    Soit "<situation>"
    Quand je dis "<demande>"
    Alors la demande est refusée pour vue indisponible, sans donnée ni résumé d'une autre vue

    Exemples:
      | situation                              | demande                                    |
      | le modèle n'est pas joignable          | Montre-moi la carte des crashs par pays    |
      | le modèle refuse pour vue indisponible | Affiche les crashs en fonction de la météo |

  # Automatisé (Go, orchestrateur) : TestC07_Gateway* (Relays, Rejections, UnauthorizedSource, RateLimited, DisabledWithoutModel).
  #    Le contrôle du compose (clé ou port publié chez un agent) : backend/check-compose.sh, non branché sur la porte de qualité (Q-84).
  @C-07 @NFR-09 @NFR-11
  Scénario: C-07 La passerelle relaie une demande valide, bornée, sans rien journaliser du contenu
    Soit la passerelle interne et un faux serveur de modèle
    Quand un agent autorisé envoie une demande valide
    Alors la réponse est la sortie du modèle, sans mise en cache
    Et le serveur de modèle reçoit un seul appel avec le modèle et le plafond de jetons configurés
    Et aucune clé ni aucun contenu de demande n'apparaît dans les journaux

  @C-07 @NFR-09 @NFR-11
  Plan du Scénario: C-07 La passerelle refuse toute demande non conforme avant d'appeler le modèle
    Soit la passerelle interne et un faux serveur de modèle
    Quand la requête est "<requête>"
    Alors la passerelle la refuse
    Et le serveur de modèle n'est pas appelé

    Exemples:
      | requête                                  |
      | un corps trop grand                      |
      | sans schéma                              |
      | une méthode ou un chemin inconnus        |
      | sans type JSON                           |
      | avec un en-tête d'origine                |
      | envoyée depuis une adresse non autorisée |
      | au-delà du plafond de débit              |
      | alors qu'aucun modèle n'est configuré    |

  # Automatisé (Go, orchestrateur) : TestC08_CrashListRelayedEndToEnd, TestC08_ViewUnavailableRefusal*
  @C-08 @FR-04 @RG-07 @RG-08
  Scénario: C-08 La liste des crashs demandée à la voix arrive à l'écran par l'agent Qualité seul
    Soit les trois agents réels et la liste blanche à six composants
    Quand le speaker dit "Affiche la liste des crashs"
    Alors le plan ne retient que l'agent Qualité
    Et l'application reçoit la surface "crashes" en trois temps, acceptée par la liste blanche
    Et les indicateurs et la courbe ne sont pas créés

  @C-08 @RG-08
  Scénario: C-08 Une vue indisponible est refusée à la voix avec sa propre phrase
    Soit un agent retenu qui refuse pour vue indisponible
    Quand le speaker dit "Montre-moi la carte des crashs par pays"
    Alors l'agent passe à "hors périmètre" et non à "échec", sans aucun écran publié
    Et la voix dit la phrase du refus de vue, pas celle des limites de plateforme

  # Automatisé (Flutter) : F-01
  @F-01 @FR-04 @FR-06 @NFR-06
  Scénario: F-01 La liste des crashs devient la cinquième cellule sans recréer les quatre autres
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs
    Alors la grille passe de 2 colonnes sur 2 lignes à 3 colonnes sur 2 lignes
    Et les surfaces se lisent dans l'ordre : indicateur, courbe, avis, checklist, crashs
    Et les quatre surfaces de l'acte 1 gardent leur état de rendu
    Et l'étagère affiche "5 / 6 utilisés" avec la liste des crashs "utilisée"

  # Automatisé (Flutter) : F-02, cinq scénarios (squelette puis données, lisibilité, deux états neutres)
  @F-02 @FR-04 @RG-02 @RG-10 @NFR-05
  Scénario: F-02 La liste passe par le squelette, l'absence de données puis les données, lisiblement
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs étape par étape
    Alors un squelette est visible, puis une cellule sans données, puis cinq lignes
    Et le texte fait au moins 24 px et chaque libellé tient sur une ligne, suivie d'une ellipse s'il est trop long
    Et la plateforme et le volume sont à droite ; le nombre de sessions touchées n'est pas affiché

  @F-02 @RG-10
  Plan du Scénario: F-02 Une donnée incohérente donne l'état neutre, sans erreur
    Soit le tableau de la release 3.4 est affiché
    Quand le serveur émet la liste des crashs avec "<défaut>"
    Alors la surface "crashes" affiche l'état neutre "Données indisponibles"
    Et les quatre surfaces de l'acte 1 gardent leur état de rendu

    Exemples:
      | défaut                         |
      | un champ items de mauvais type |
      | une ligne sans libellé         |
