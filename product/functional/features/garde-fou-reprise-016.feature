# language: fr
# id: p-fn-feature-garde-fou-reprise-016
# Scénarios de la fonctionnalité 016 « consigne de silence livrée » (livrée le 2026-10-31, gate --full vert, 67 contrôles) :
#    G-01 et G-02 (le texte de la consigne de silence est livré au fournisseur) et R-01 à R-11 (reprise d'une demande
#    dite par-dessus l'IA, mal transcrite puis refusée : « pouvez-vous répéter ? »). Hors des 9 scénarios de la fiche (DoD : S-01 à S-09, pdr-0049).
# ⚠️ G-01 et G-02 prouvent que le TEXTE de la consigne est livré, jamais que l'IA se tait. Un essai réel d'un seul échantillon
#    (« Papa, papa » : aucune délégation ni sortie ; « Explique-moi la checklist » : déléguée) ne démontre pas que la consigne tient : Q-89, Q-90 (à confirmer en répétition).
# Décisions : pdr-0081 D2 (porteur : « Elle ne doit pas la traiter. C'est un bruit parrasite », 2026-10-31), pdr-0082 (moyen, boucle sous pdr-0062).
#    Exigences : FR-13, FR-14, FR-17, FR-19 ; règles RG-11, RG-12, RG-15, RG-17, RG-26, RG-27 ; NFR-02 (l'accusé n'est pas dégradé).
# Automatisation (Go, tag acceptance) : backend/orchestrator/bootstrap/voice_instructions_guard_test.go (G-01, G-02) ;
#    backend/orchestrator/acceptance/recovery_test.go et recovery_helpers_test.go (R-00 : lecture de VOICE_RECOVERY_WINDOW dans le compose sans repli, R-01 à R-11).
#    Les R-xx de 016 sont distincts des R-01 à R-09 de 010 (rejeu, status.md de 010).
# Le détail du mécanisme : p-ar-voice-recovery. Steps sans chiffre initial (pdr-0022-gherkin-steps-no-leading-digit).

Fonctionnalité: Consigne de silence et reprise d'une demande mal comprise après un chevauchement

  # Automatisé (Go) : G-01. Le texte seul est contrôlé : la ligne est repérée par un marqueur stable, la forme est le critère.
  @G-01 @FR-13 @FR-19
  Scénario: G-01 Le fichier d'instructions vocales contient la consigne de silence
    Soit le fichier voice-instructions.fr.md livré avec l'orchestrateur
    Alors une seule ligne dit de ne pas répondre à ce qui n'est pas une parole intelligible adressée à l'assistant (bruit, voix lointaine, bribe sans demande)
    Et cette ligne interdit aussi de demander "tu es là ?" et de déléguer
    Et elle garde l'exception "une demande d'affichage, même hors sujet, ou une question sur la release reste déléguée", placée après la directive
    Et elle suit les consignes de délégation, dont les textes exacts de 012 sont intacts
    Et le critère est la forme de l'énoncé et non son sujet

  # Automatisé (Go) : G-02. Serveur httptest qui lit session.instructions ; le vrai fichier, pas un texte de test.
  @G-02 @FR-13
  Scénario: G-02 Le texte du vrai fichier arrive au fournisseur
    Soit newOpenAI construit avec le vrai fichier d'instructions et un serveur de test
    Quand la session est créée
    Alors le champ session.instructions reçu contient la consigne de silence

  # Automatisé (Go) : R-01. Fenêtre du compose (8 s) ; la phrase dite est no_request, jamais le refus de vue.
  @R-01 @FR-13 @FR-14 @RG-08
  Scénario: R-01 Une demande dite par-dessus l'IA et refusée par tous les agents invite à répéter
    Soit un chevauchement publié à at_ms et la fenêtre de reprise de 8 s
    Quand le speaker dit une demande d'offset au moins égal à at_ms, que tous les agents retenus refusent
    Alors la voix dit la phrase no_request "Je n'ai pas bien saisi la demande, pouvez-vous répéter ?"
    Et elle ne dit ni failure_rejected_view ni failure_rejected

  # Automatisé (Go) : R-02.
  @R-02 @FR-14 @RG-08
  Scénario: R-02 La même demande au calme reçoit le refus habituel
    Soit aucun chevauchement n'a eu lieu
    Quand le speaker dit la même demande, refusée par tous les agents
    Alors la voix dit le refus habituel (failure_rejected_view ou failure_rejected), inchangé

  # Automatisé (Go) : R-03.
  @R-03 @FR-14
  Scénario: R-03 Une demande dite par-dessus l'IA et réussie ne déclenche aucune reprise
    Soit un chevauchement publié et une demande dite par-dessus l'IA
    Quand les agents la traitent avec succès
    Alors le résultat habituel est commenté
    Et aucune phrase de reprise n'est dite

  # Automatisé (Go) : R-04. Bornes incluses.
  @R-04 @FR-13 @FR-14
  Scénario: R-04 La reprise est bornée par la fenêtre
    Soit un chevauchement publié à at_ms et la fenêtre de reprise
    Quand la demande refusée a pour offset exactement at_ms plus la fenêtre
    Alors la voix dit la phrase no_request
    Quand une autre demande refusée a un offset supérieur à at_ms plus la fenêtre
    Alors la voix dit le refus habituel

  # Automatisé (Go) : R-05.
  @R-05 @FR-13 @FR-14 @RG-08
  Scénario: R-05 Aucun agent retenu après un chevauchement
    Soit un chevauchement publié et une demande dite par-dessus l'IA
    Quand aucun agent n'est retenu pour cette demande
    Alors la voix dit la phrase no_request et non out_of_catalog

  # Automatisé (Go) : R-06. Code : fenêtre à 0 ; compose : 8 s. Jamais de refus de démarrage.
  @R-06 @FR-13
  Scénario: R-06 La fenêtre vaut zéro, ou le chevauchement est coupé
    Soit VOICE_RECOVERY_WINDOW vaut 0 (défaut du code)
    Quand une demande dite par-dessus l'IA est refusée
    Alors le comportement de 015 est inchangé : refus habituel
    Quand la fenêtre est supérieure à 0 et VOICE_OVERLAP_INTERRUPT vaut false
    Alors le démarrage réussit, un avertissement est journalisé et le comportement est celui de 014

  # Automatisé (Go) : R-07.
  @R-07 @FR-14
  Scénario: R-07 Après la reprise, la même demande répétée au calme est planifiée
    Soit la phrase no_request vient d'être dite
    Quand le speaker répète sa demande au calme
    Alors elle est planifiée normalement et reçoit son résultat

  # Automatisé (Go) : R-08. RG-08 est différé d'un tour, jamais supprimé.
  @R-08 @FR-13 @FR-14 @RG-08
  Scénario: R-08 Un seul passage : la répétition par-dessus la phrase de reprise reçoit le refus habituel
    Soit une demande refusée après un chevauchement, suivie de la phrase no_request
    Quand le speaker répète par-dessus cette phrase (nouveau chevauchement) et que la demande est refusée de nouveau
    Alors la voix dit le refus habituel avec son alternative, jamais une seconde phrase no_request

  # Automatisé (Go) : R-09. Comportement assumé (hypothèse non confirmée) : voir p-ar-voice-recovery.
  @R-09 @FR-13 @FR-19
  Scénario: R-09 Une bribe sans sens déléguée malgré la consigne reçoit l'invitation à répéter
    Soit une bribe sans sens ("Papa Papa") dite par-dessus l'IA, que le modèle délègue malgré la consigne de silence
    Quand tous les agents refusent ou qu'aucun n'est retenu
    Alors la voix dit la phrase no_request

  # Automatisé (Go) : R-10.
  @R-10 @FR-14 @FR-17
  Scénario: R-10 Une correction dite pendant que l'IA parle, puis refusée, déclenche la reprise
    Soit l'IA parle et le speaker dit une correction ("Non, plutôt sur Android") par-dessus elle
    Quand la demande corrigée est refusée par tous les agents
    Alors la voix dit la phrase no_request

  # Automatisé (Go) : R-11. Échecs d'agent et mélange refus et échec : phrase habituelle.
  @R-11 @FR-14 @RG-12
  Scénario: R-11 Un échec d'agent après un chevauchement garde la phrase d'échec habituelle
    Soit un chevauchement publié et une demande dite par-dessus l'IA
    Quand un agent échoue, seul ou mêlé à des refus
    Alors la voix dit la phrase d'échec habituelle et non no_request
