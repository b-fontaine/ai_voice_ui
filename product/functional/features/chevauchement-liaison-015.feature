# language: fr
# id: p-fn-feature-chevauchement-liaison-015
# Scénarios de la fonctionnalité 015 « 011b » (livrée le 2026-10-31, gate --full vert, 67 contrôles) : S-05 sans mot d'arrêt,
#    O-01 à O-08 (couper la parole à l'IA en parlant, Go) et L-01 à L-04 (liaison animée de délégation du rail, Flutter).
#    Hors des 9 scénarios de la fiche (la DoD reste S-01 à S-09, pdr-0049) ; S-05 est aussi dans barge-in.feature.
# Décisions : pdr-0077 (porteur : Q-77 le 2026-10-30, Q-85 le 2026-10-31), pdr-0080 (D1 à D6, boucle sous pdr-0062).
#    Exigences : p-fn-requirements (FR-03, FR-13, FR-15, FR-18, FR-19) ; règles : RG-11, RG-16, RG-17 ; NFR-04.
# Automatisation : Flutter = apps/genesis_canvas/test/acceptance/acte_chevauchement_liaison.feature (S-05, O-01 côté app, L-01 à L-04) ;
#    Go (tag acceptance) = backend/orchestrator/acceptance/overlap_trigger_test.go (O-01, O-04, O-07), overlap_filter_test.go (O-02, O-03)
#    et overlap_inflight_test.go (O-05, O-06, O-08) ; toute l'acceptation Go tourne avec les valeurs du compose (VOICE_OVERLAP_*).
# Hypothèses non confirmées en réel : faux positifs d'écho sans AEC, latence ≈ 1 s, fenêtre de parole de 2 s (Q-80, SP-06).
# Le détail des mots significatifs, de la garde et de l'effet : p-ar-voice-overlap. Steps sans chiffre initial (pdr-0022-gherkin-steps-no-leading-digit).

Fonctionnalité: Couper la parole à l'IA en parlant, et liaison animée de délégation

  # Automatisé (Flutter) : S-05 et ses variantes, S-05 bis (délégation avant l'interruption).
  @S-05 @FR-13 @FR-15 @FR-19
  Scénario: S-05 Interrompre l'IA pendant qu'elle parle, sans mot d'arrêt
    Soit l'IA est en train de commenter le tableau de release
    Quand je commence à parler, sans dire "Stop"
    Alors l'IA se tait
    Et l'orbe passe à l'état "Interrompue" puis "Écoute"
    Et sa réplique est tronquée dans la transcription à l'endroit de l'interruption
    Et les surfaces déjà affichées restent en place

  # Automatisé (Go) : TestO01. at_ms = start_ms du premier delta de l'énoncé ; la session reste ouverte.
  @O-01 @FR-13 @FR-19
  Scénario: O-01 Une phrase du speaker pendant que l'IA parle coupe sa voix
    Soit le chevauchement est activé et l'IA parle (audio de sortie à niveau fort, transcription de sortie)
    Quand le speaker dit "Affiche la sécurité Android", sans mot d'arrêt
    Alors un seul message voice.interrupted de cause "overlap" est publié, daté du début de l'énoncé
    Et la session reste ouverte
    Et la piste distante est coupée et l'orbe passe à "Interrompue" puis "Écoute"

  # Automatisé (Go) : TestO02 (écho) et variante nombre. Les deltas sont des fragments de mot.
  @O-02 @FR-18 @FR-13
  Scénario: O-02 L'écho de l'IA ne déclenche rien
    Soit l'IA dit "Je vérifie Android" (reçu en fragments "Andr" puis "oid")
    Quand l'entrée du speaker reprend ces mots, "Andr" puis "oid" puis "vérifie"
    Alors aucun voice.interrupted n'est publié
    Quand le speaker dit ensuite un mot hors écho, "Affiche sécurité"
    Alors un seul voice.interrupted de cause "overlap" est publié
    # variante : un nombre repris de l'IA ("la 3.3") ne déclenche rien non plus, un nombre hors écho ("4.1") déclenche une fois

  # Automatisé (Go) : TestO03. Un nombre est dispensé de la longueur et de la liste ignorée, jamais de l'écho.
  @O-03 @FR-18
  Scénario: O-03 Mots vides, mots trop courts et bruits ne déclenchent rien
    Soit l'IA parle
    Quand le speaker dit des mots vides, des mots trop courts ou des bruits ("euh", "hum")
    Alors aucun voice.interrupted n'est publié
    Quand le speaker dit un mot significatif, ou un nombre comme "3.3"
    Alors un seul voice.interrupted de cause "overlap" est publié

  # Automatisé (Go) : TestO04. Code : chevauchement coupé par défaut ; compose : activé.
  @O-04 @FR-13
  Scénario: O-04 L'interrupteur VOICE_OVERLAP_INTERRUPT
    Soit le même script d'énoncé par-dessus la voix de l'IA
    Quand VOICE_OVERLAP_INTERRUPT vaut false
    Alors le comportement de 014 est inchangé : aucun voice.interrupted
    Quand VOICE_OVERLAP_INTERRUPT vaut true
    Alors un seul voice.interrupted de cause "overlap" est publié

  # Automatisé (Go) : TestO05, agent A2A scripté bloquant. Supersede, jamais Interrupt.
  @O-05 @FR-13 @FR-14 @FR-15
  Scénario: O-05 Une exécution est en vol quand le speaker parle par-dessus l'IA
    Soit une exécution en vol : deux surfaces complètes, une sans données, une seulement créée
    Quand le speaker dit "Android et la sécurité" par-dessus la voix de l'IA
    Alors voice.interrupted de cause "overlap" est publié avant toute compensation
    Et l'exécution antérieure est annulée
    Et les deux surfaces inachevées sont retirées, les deux complètes restent
    Et la demande du speaker est planifiée, avec ses mots de tête, sans rien de la demande antérieure

  # Automatisé (Go) : TestO06. Priorité correction, arrêt, chevauchement ; anti-rebond asymétrique.
  @O-06 @FR-13 @FR-14 @FR-17
  Scénario: O-06 Stop et mots de correction gardent leur propre cause
    Soit le chevauchement, les mots d'arrêt et les mots de correction sont configurés et l'IA parle
    Quand le speaker dit "Stop."
    Alors un seul voice.interrupted de cause "stop" est publié, jamais un second de cause "overlap"
    Quand le speaker dit "Non, plutôt iOS."
    Alors un seul voice.interrupted de cause "correction" est publié, avec ou sans exécution en vol
    Quand le speaker dit "Stop, montre plutôt Android pour la 3.3."
    Alors l'énoncé, trop long pour un "Stop", est évalué en chevauchement : un seul voice.interrupted de cause "overlap"

  # Automatisé (Go) : TestO07. Le flux d'audio de sortie est continu, à niveau nul quand l'IA se tait (garde verrouillée à l'ouverture).
  @O-07 @FR-13
  Scénario: O-07 L'IA ne parle pas, le tour de parole est ordinaire
    Soit le flux d'audio de sortie continue à niveau nul
    Quand le speaker dit "Montre la sécurité"
    Alors aucun voice.interrupted n'est publié
    Quand l'IA parle puis que le speaker dit la même phrase par-dessus elle
    Alors un seul voice.interrupted de cause "overlap" est publié

  # Automatisé (Go) : TestO08. ⚠️ Cas décidé par pdr-0077, atténué par la liste de mots ignorés ; à juger par le porteur en répétition.
  @O-08 @FR-13
  Scénario: O-08 Le speaker commente par-dessus l'accusé de sa propre demande
    Soit la demande du speaker est en vol et l'IA l'accuse ("Je prépare la release 3.4")
    Quand le speaker dit "super" par-dessus l'accusé
    Alors avec "super" dans la liste des mots ignorés, rien ne se passe et l'exécution continue
    Mais sans ce mot dans la liste, la demande en vol est annulée par voice.interrupted de cause "overlap", et le canevas reste interrompu faute de nouvelle délégation (Q-87)

  # Automatisé (Flutter) : L-01 (acceptation, polices réelles). Trait pointillé de l'orchestrateur à chaque tuile, clé delegation-link-<agent>.
  @L-01 @FR-03 @NFR-04
  Scénario: L-01 Une liaison relie l'orchestrateur à chaque agent en attente ou en cours
    Soit un plan qui retient trois agents, dont deux au travail et un en attente
    Alors une liaison de délégation relie l'orchestrateur à la tuile de chacun des trois agents

  # Automatisé (Flutter) : L-02, un scénario par état terminal.
  @L-02 @FR-03 @NFR-04
  Scénario: L-02 La liaison disparaît dès que l'agent n'est plus sollicité
    Soit un agent relié à l'orchestrateur
    Quand il passe à l'état "terminé", "échec", "hors périmètre" ou "interrompu"
    Alors sa liaison n'est plus affichée et celle des autres agents reste
    Quand le plan est vide ("aucun agent retenu")
    Alors aucune liaison n'est affichée

  # Automatisé (Flutter) : L-03, avec un témoin (animations actives : les pointillés défilent).
  @L-03 @FR-03 @NFR-04
  Scénario: L-03 Animations coupées, la liaison reste fixe
    Soit les animations du système sont désactivées (SceneMotionScope.disabled)
    Et un agent relié à l'orchestrateur
    Quand le temps passe
    Alors la liaison reste affichée et son image ne change pas

  # Automatisé (Flutter) : L-04. Le rail garde les tuiles du dernier direct en rejeu (Q-88 tranchée → pdr-0081). Seule l'absence de liaison est testée.
  @L-04 @FR-03 @FR-09
  Scénario: L-04 Pendant le rejeu, aucune liaison n'est affichée
    Soit un direct dont les agents sont terminés
    Quand je clique sur Lecture et que le rejeu avance
    Alors aucune liaison de délégation n'est affichée
