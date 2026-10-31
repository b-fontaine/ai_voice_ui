# 015 — Plan technique (amendé par la revue du plan : P1 à P8)

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Go | `internal/domain` | domain | `CauseOverlap InterruptCause = "overlap"` |
| Go | `internal/app/voice` | app | `overlap.go` : `OverlapFilter` pur (jetons fermés, mots significatifs, liste ignorée, écho de sortie, garde) ; `StopDetector` : `KindOverlap`, priorité, anti-rebond asymétrique ; `StopConfig.Active()` (factorise la condition de construction, aujourd'hui dupliquée dans `NewService` et `newStopWatch`) ; `stopWatch` : `NoteOutput(level)` / `FeedOutput(delta)` ; `supervise` : alimentation depuis le niveau déjà calculé par `translate` ; `onDetection` : `KindOverlap` → `announceInterrupted(overlap)` puis `fw.supersede(atMs, nil)` ; `KindCorrection` avec chevauchement actif et garde vraie → `announceInterrupted(correction)` dans `supervise`, puis `fw.supersede(atMs, nil)` |
| Go | `internal/bootstrap` | config | `VOICE_OVERLAP_*` lues, bornées, validées (`Options.Stop.Overlap`) |
| Go | `backend/orchestrator/acceptance` | tests (tag `acceptance`) | O-01 à O-08, sans référencer `OverlapFilter` ; rejeu des suites 011 et 014 avec les valeurs du compose |
| Flutter | `packages/entities/session` | entities | `InterruptionCause.overlap` |
| Flutter | `packages/features/voice_session` | api, model | convertisseur (inconnu = `stop`) ; `OrbPhaseBloc` : `_InterruptionKind.overlap` |
| Flutter | `packages/shared/design_system` | tokens | jeton `motionLink` (période de défilement), `SceneMotionScope.loop` |
| Flutter | `apps/genesis_canvas/lib/widgets/agents_rail` | widgets | `delegation_link_geometry.dart`, `delegation_link_painter.dart`, `delegation_links.dart` ; `agents_rail.dart` |
| Flutter | `apps/genesis_canvas/test/acceptance` | tests | S-05, O-01 (app), L-01 à L-04 |
| Compose | `docker-compose.yaml` | config | `VOICE_OVERLAP_*` — session principale seulement |

## Configuration : défauts et bornes (P1, P8)
| Variable | Rôle | Défaut du code ; compose | Bornes |
|---|---|---|---|
| `VOICE_OVERLAP_INTERRUPT` | active le chevauchement | coupé ; **activé** | booléen |
| `VOICE_OVERLAP_SPEAKING_LEVEL` | niveau de sortie à partir duquel l'IA « parle » | — ; 0,02 | 0 < x ≤ 1 |
| `VOICE_OVERLAP_SPEAKING_WINDOW` | ancienneté maximale de la dernière parole de l'IA | — ; 2 s (≥ latence de transcription + auto-coupure du fournisseur) | 200 ms à 10 s |
| `VOICE_OVERLAP_ECHO_WINDOW` | fenêtre média des mots de sortie tenus pour écho | — ; 8 s | 1 à 60 s |
| `VOICE_OVERLAP_MIN_WORDS` | mots significatifs distincts requis | — ; 1 | 1 à 8 |
| `VOICE_OVERLAP_MIN_WORD_LEN` | longueur minimale d'un mot (runes) ; un nombre est toujours significatif | — ; 3 | 1 à 16 |
| `VOICE_OVERLAP_IGNORE_WORDS` | mots vides, interjections, acquiescements | vide ; mots vides français et `ok,oui,super,merci,d'accord,parfait,voilà,vas-y,euh,hum` | ≤ 64 mots de 32 runes |

Valeurs de départ, à régler en répétition (Q-80).

## Contrats
- **Garde « l'IA parle » (B1)** : horloge injectée (`port.Clock`), jamais `time.Now`. `NoteOutput(level)` reçoit le niveau que `sess.meter.Write` calcule déjà dans `translate` (un seul calcul RMS) ; un delta de transcription de sortie compte aussi. Verrouillée au premier delta de l'énoncé (état `speakingAtOpen`), remise à zéro à l'ouverture de l'énoncé suivant. Aucun état hors de la goroutine de `supervise`. Les blocs d'audio de sortie arrivent toutes les **200 ms**.
- **Jetons (B2)** : seuls les jetons fermés sont jugés (`Tokenize` rend le drapeau `closed`) ; le dernier jeton ouvert l'est au delta suivant ou à `Settle` (`PendingFor`/`SettleNow` couvrent le chevauchement en attente). Écho : texte concaténé des deltas de sortie, jetons fermés ; mémo = file `(mot, end_ms)` + compteur par mot, élagué sur `[maxEnd − ECHO_WINDOW, maxEnd]` (horloge média, hypothèse de Q-80), plafonné à 256. Un jeton de chiffres seulement est significatif quelle que soit sa longueur (« 3.3 » compte).
- **Priorité (B3)** : (1) tête de correction ou début d'un mot de correction (`corr.CouldStart`), (2) tête d'arrêt ou début d'un mot d'arrêt (`CouldStart`), (3) chevauchement. Un Stop écarté pour longueur n'a pas `fired` pour le chevauchement. Anti-rebond asymétrique (Overlap après Stop ou Correction filtré ; Stop jamais filtré par un Overlap). Une ligne par cas dans la table de T22.
- **Effet (B4)** : `at_ms` = `start_ms` du premier delta de l'énoncé. `announceInterrupted` **avant** `fw.supersede(atMs, nil)` (`Supersede` accepte `nil`, ligne 77 de `supersede.go`) : l'annonce part dans `supervise` avant la mise en file, l'ordre « annonce avant annulation » de 014 est donc conservé. Un seul `voice.interrupted` par énoncé dans tous les cas (test de non-doublon). `Interrupt` n'est jamais utilisé. Correction pendant que l'IA parle sans exécution en vol : `voice.interrupted {correction}` publié par `supervise` (chevauchement actif et garde vraie), `Supersede` sans annonce ; sans chevauchement actif : comportement de 014.
- **Interrupteur (B6)** : valeur nulle = coupé. Chevauchement coupé : tous les tests de 011 et 014 passent inchangés. `StopConfig.Active()` (arrêt, correction ou chevauchement) décide de la construction du classifieur, testée en T22. Une tâche rejoue toute la suite d'acceptation de 011 et 014 avec les valeurs du compose.
- **App-channel** : `cause ∈ {stop, correction, overlap}`, inconnu = `stop` côté app. Pas de nouveau message.
- **Orbe (P6)** : `overlap` reçu alors que la phase n'est pas `Speaking` → `Interrupted` puis `Listening` aussitôt (la page coupe puis rétablit la piste). Sinon comme `correction` (fin à la première délégation d'offset ≥ `at_ms`, ou au silence de reprise).
- **Liaison (P7)** : `SceneMotionScope.loop(controller, base)` : période nulle (`disabled`) → `stop()`, phase fixe ; sinon `repeat(period: durationFor(base))` ; jeton `motionLink`. `State` avec `SingleTickerProviderStateMixin` ; `repeat`/`stop` recalculés dans `didChangeDependencies` (scope) et `didUpdateWidget` (ensemble des liens) ; contrôleur arrêté sans lien, libéré dans `dispose`. `CustomPainter(repaint: controller)`, ni `AnimatedBuilder` ni `setState` par image ; `RepaintBoundary` autour du seul `CustomPaint` ; chemin pointillé mis en cache par géométrie, seule la phase change ; préfixe de tracé identique pour tous les liens. Mesure des tuiles par `GlobalKey` sur un `KeyedSubtree` autour de chaque tuile (la `Column` garde `Key('agent-<nom>')`, les clés des agents disparus sont libérées), refaite aussi au changement de contraintes (`LayoutBuilder`), `setState` seulement si les rectangles changent. Le filtre par état (en attente ou en cours) est dans `DelegationLinks`, pas dans le peintre. Place verticale : 96 − 2 × (24 × 1,3) ≈ 16,8 px au-dessus des tuiles, l'arc y reste. Contraste 3:1 (élément graphique).
- **Dart** : Bloc uniquement, états et events `sealed`, aucun `getIt` dans un widget ou un Bloc. Couleurs du thème de scène.

## Références
- `product/architecture/voice-interruption.md`, `frontend-screen.md`, `screen.md` § Rail, `app-channel-contract.md`.
- Notes `knowledge/` : [rt-barge-in], [rt-transcription], [rt-gpt-live-output-level], [rt-gpt-live-delegation-latency], [rt-echo-cancellation], [ux-voice-multimodal].

## Risques
- **Garde toujours vraie** (flux de sortie continu) → seuil de niveau, verrouillage à l'ouverture de l'énoncé, test avec silence continu (O-07).
- **Fragments de mot** (« Andr|oid ») → jetons fermés seulement, test de table.
- **Faux positifs d'écho** sans AEC → filtre par mots, valeurs de départ prudentes, interrupteur ; à régler en répétition.
- **Double `voice.interrupted`** → priorité, annonce unique, test de non-doublon.
- **Demande du speaker consommée ou annulée** → `at_ms` au premier delta ; `Supersede` conserve l'offset ≥ `at_ms` ; cas du commentaire sur sa propre demande documenté, signalé au porteur.
- **Suites 011 et 014 perturbées** (faux fournisseur qui émet audio et transcripts de sortie) → code coupé par défaut, tâche de rejeu avec les valeurs du compose.
- **Liaison qui masque un libellé, se fige ou fait chuter les images** → arc au-dessus des pastilles, `RepaintBoundary`, tests T12a/T12b ; mesure au profil laissée à J7.
