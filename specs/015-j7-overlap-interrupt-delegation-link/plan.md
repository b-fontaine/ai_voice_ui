# 015 — Plan technique

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Go | `backend/orchestrator/internal/domain` | domain | `CauseOverlap InterruptCause = "overlap"` (énumération fermée de `VoiceInterrupted`) |
| Go | `backend/orchestrator/internal/app/voice` | app | `overlap.go` : filtre pur `OverlapFilter` (mots significatifs, liste ignorée, écho de sortie sur fenêtre média) ; `StopDetector` : troisième genre `KindOverlap`, sous-ordre de priorité (arrêt et correction d'abord) ; `stopWatch` : alimentation par les deltas de **sortie** (`FeedOutput`) et par l'instant de dernière sortie (`NoteOutput`) ; `supervise` : suit `EventOutputAudio` et `EventOutputTranscriptDelta` ; `onDetection` : `KindOverlap` → `announceInterrupted(cause overlap)` puis `fw.supersede(atMs, no-op)` |
| Go | `backend/orchestrator/internal/bootstrap` | config | `VOICE_OVERLAP_*` lues, bornées et validées (`Options.Stop.Overlap`) ; message d'erreur sans recopier de mot |
| Go | `backend/orchestrator/acceptance` | tests (tag `acceptance`) | O-01 à O-07 (faux fournisseur, agents scriptés bloquants), sans référencer `OverlapFilter` |
| Flutter | `packages/entities/session` | entities | `InterruptionCause.overlap` |
| Flutter | `packages/features/voice_session` | api, model | `session_event_converter.dart` (`overlap` accepté, inconnu = `stop`) ; `OrbPhaseBloc` : `_InterruptionKind.overlap` traité comme `correction` (fin à la première délégation d'offset ≥ `at_ms`) |
| Flutter | `apps/genesis_canvas/lib/widgets/agents_rail` | widgets | `delegation_link.dart` : `DelegationLinkPainter` (pointillés, phase animée), `DelegationLinks` (Stack sous les tuiles, mesure des tuiles) ; `agents_rail.dart` y branche les agents « en attente » ou « en cours » ; la constante `delegationGap` devient l'intervalle de départ du trait |
| Flutter | `apps/genesis_canvas/test/acceptance` | tests | S-05, O-01 (côté app), L-01 à L-04 |
| Compose | `docker-compose.yaml` | config | `VOICE_OVERLAP_*` — fichier partagé : session principale seulement |

## Contrats
- **Garde « l'IA parle » (B1)** : horloge injectée (`port.Clock`), jamais `time.Now`. `NoteOutput` est appelé pour `EventOutputAudio` (toutes les 20 ms environ) et pour chaque delta de sortie : c'est la seule source de vérité. Aucun état partagé hors de la goroutine de `supervise` (le filtre n'est pas sûr pour l'accès concurrent, comme `StopDetector`).
- **Écho (B2)** : l'ensemble est calculé sur la **transcription de sortie** de la fenêtre média `[maxEnd − VOICE_OVERLAP_ECHO_WINDOW, maxEnd]` (`start_ms`/`end_ms` des deltas), pas sur l'horloge murale : les deux transcripts partagent l'horloge média (hypothèse de Q-80). Mots normalisés par `stopword.Tokenize` (même normalisation que les mots d'arrêt). Le mémo est borné (au plus 256 mots) ; au-delà, le plus ancien est écarté.
- **Priorité (B3)** : le classifieur teste dans l'ordre (1) tête de correction, (2) tête d'arrêt ou début d'un mot d'arrêt (`CouldStart`), (3) chevauchement. Un énoncé qui est ou pourrait être un « Stop » en attente de confirmation ne déclenche jamais `Overlap` ; en revanche un énoncé tranché `fired` ne repasse pas par le chevauchement. `Debounce` partagé : un `Overlap` ne suit pas un déclencheur de moins de `VOICE_STOP_DEBOUNCE`.
- **Effet (B4)** : `announceInterrupted` **avant** `supersede` (ordre de 014 : `announce` avant `cancel`). `supersede` est appelé avec un `announce` vide ; `Supersede` n'annonce donc rien de plus, et l'unique `voice.interrupted` est celui d'`Overlap`. `Interrupt` n'est jamais utilisé.
- **Interrupteur (B6)** : `VOICE_OVERLAP_INTERRUPT=false` ou aucune des deux listes d'arrêt ni de correction : le détecteur existant se comporte exactement comme avant (tests de non-régression de 011 et 014 inchangés). Le chevauchement peut fonctionner **sans** mot d'arrêt ni mot de correction configurés : le classifieur est construit dès que l'une des trois détections est active.
- **App-channel** : `voice.interrupted {at_ms, cause?}`, `cause ∈ {stop, correction, overlap}`. Pas de nouveau message, pas de nouvelle version. Le journal JSONL garde le message, `ReplayRouter` l'ignore (comme aujourd'hui).
- **Liaison (A2)** : le rail mesure les tuiles par `GlobalKey` après la mise en page (`addPostFrameCallback` borné à un passage par changement de plan), pas par `LayoutBuilder` + hypothèses de largeur. Le trait part du bord droit de la tuile `agent-orchestrator` (centre vertical de la pastille) et rejoint le bord gauche de la tuile de l'agent par un arc qui passe **au-dessus** de la rangée de pastilles (entre le repère et le haut de la tuile) pour ne rien couvrir. `AnimationController` unique pour tous les traits (une phase), `SceneMotionScope.play` pour respecter `disabled` et la vitesse ; contrôleur arrêté quand aucun trait n'est visible. `RepaintBoundary` autour du `CustomPaint`.
- **Dart** : Bloc uniquement, états et events `sealed`, aucun `getIt` dans un widget ou un Bloc. Tokens de la scène (couleur `theme.accent`), aucune valeur de couleur codée.

## Références
- `product/architecture/voice-interruption.md` (§ Correction en vol, § Détecteur), `frontend-screen.md`, `screen.md` § Rail, `app-channel-contract.md`.
- Notes `knowledge/` : [rt-barge-in], [rt-transcription], [rt-gpt-live-delegation-latency], [rt-echo-cancellation], [ux-voice-multimodal].

## Risques
- **Faux positifs d'écho** (sans AEC, la voix de l'IA revient dans le micro) → filtre d'écho par mots, mais une transcription d'entrée qui déforme un mot de l'IA passe le filtre. Défauts prudents (`MIN_WORDS` 2 dans le compose si `1` s'avère bruyant : à régler en répétition), interrupteur `VOICE_OVERLAP_INTERRUPT` à portée du porteur.
- **Double `voice.interrupted`** (arrêt puis chevauchement sur le même énoncé) → priorité du classifieur, un test d'énoncé « Stop » mot à mot et un test de non-doublon (O-06).
- **Demande du speaker annulée par son propre déclencheur** → `Supersede` (offset ≥ `at_ms` conservé), jamais `Interrupt` ; O-05.
- **Coupure sans effet côté fournisseur** : GPT-Live coupe déjà sa propre génération sur la VAD du serveur ; notre `voice.interrupted` coupe la piste distante côté app. Aucun message n'est envoyé au fournisseur (aucune annulation de réponse inventée).
- **Liaison qui masque un libellé ou ne se repeint pas** → arc au-dessus des pastilles, mesure par `GlobalKey`, test de capture 1920×1080 et widget test sur la tuile la plus éloignée.
- **60 i/s (NFR-04)** → un seul contrôleur, un seul `CustomPaint` isolé ; mesure au profil laissée à J7.
