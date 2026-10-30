# 010 — Plan technique

Pile **Flutter seule** (aucun changement Go, aucun changement du contrat `genesis/v1`). Le rejeu réutilise le chemin de validation de 007 : un seul flux de `SessionEvent` entre dans l'`A2uiGate`, en direct comme en rejeu (pdr-0066 D2).

## Où
| Pile | Paquet / module | Couche ou slice | Fichiers créés ou modifiés |
|---|---|---|---|
| Flutter | `packages/entities/session` | entité | `A2uiJournal`, `JournalEntry` (ajout, `toJsonl`/`fromJsonl`, ordre `seq`, `t_ms` croissant) |
| Flutter | `packages/features/replay` (**nouvelle slice**, à ajouter au workspace racine) | model | `ReplayRouter` (flux vivant → journal + gate, ou lecteur → gate), `ReplayPlayer` (horloge virtuelle), `ReplayBloc`, états/événements scellés, `ReplaySettings`, port `ReplayStage` |
| Flutter | `apps/genesis_canvas` | widgets, pages, app | `ReplayBar` (commandes actives), `StageBar` (« Acte 4 · Rejeu »), `GenesisCanvasPage` (câblage, `_scenarioMode` pour l'ancien `_replayMode`), `GenesisCanvasPageSettings.replayMaxGap`, DI si besoin, `acceptance/acte4_rejouer.feature` |
| Flutter | `testing/backend_fakes`, `apps/genesis_canvas/test/acceptance/support` | doubles | pas à pas : horloge virtuelle du lecteur, compteur de requêtes du faux backend pendant le rejeu |

## Contrats
- **Journal** (`entity_session`) : `JournalEntry {seq, tMs, raw, message, agent, task}` ; `A2uiJournal.append(A2uiEnvelopeReceived, nowMs)` (le `t_ms` est relatif au premier message), `entries`, `clear()`, `toJsonl()` ; lecture `{t_ms, message}` plus `seq`, `agent`, `task` facultatifs (même format que `A2uiReplaySource` : le rejeu scripté de 000 lit un journal).
- **`ReplayRouter`** : constructeur `(live: Stream<SessionEvent>, journal, clock)` ; expose `Stream<SessionEvent> events` (abonné unique, branché une fois sur le gate). Mode `live` : chaque `A2uiEnvelopeReceived` est enregistré puis transmis ; les autres événements ne passent pas (le gate les ignore déjà). Mode `replay` : les événements vivants sont **jetés** (ni transmis, ni enregistrés) ; le lecteur y injecte les siens (`inject`). Ne ferme pas le gate à la fin du rejeu.
- **`ReplayPlayer`** (Dart pur, horloge et minuteur injectés par un port `ReplayClock`) : entrées = `List<JournalEntry>`, `maxGap`, vitesse, position. `play()`, `pause()`, `seek(position)` (réinjecte `[0, position]` d'un coup après `stage.clear()`), `setSpeed`, `restart`. Position = axe comprimé (écart plafonné à `maxGap`). Émet les entrées via `ReplayStage.emit`, `positionChanged`/`ended`.
- **`ReplayStage`** (port implémenté par la page) : `enter()` (vide le canevas sans le backend), `clear()` (= étapes 1 et 2 de `_resetStage` : `gate.reset()` puis ordres aux Blocs canevas, panneau, étagère ; **pas** d'appel backend ni de remise à zéro de l'acte), `emit(A2uiEnvelopeReceived)`, `exit()` (= `_resetStage()` complet).
- **`ReplayBloc`** : événements scellés `ReplayPlayPressed`, `ReplayPausePressed`, `ReplayRestartPressed`, `ReplaySpeedSelected(speed)`, `ReplaySeeked(position)`, `ReplayDirectPressed`, `ReplayJournalGrew(count)`, `ReplayBusyChanged(bool)` ; états scellés `ReplayLive {count, canPlay}` / `ReplayActive {position, duration, speed, status: playing|paused|ended}` ; transformer `sequential()` (un `seek` ne double pas une lecture). L'état est **dérivé** du lecteur ; le Bloc ne touche aucun autre Bloc (la page coordonne par le port).
- **Configuration injectée** : `replayMaxGap` (3 s) dans `GenesisCanvasPageSettings` ; vitesses `[0,25 ; 0,5 ; 1 ; 1,5 ; 2]` dans `ReplaySettings`.
- **UI** : `ReplayBar` lit `ReplayBloc` (jamais `getIt`) ; état Direct : « Lecture » actif si `canPlay`, le reste grisé ; état Rejeu : Lecture/Pause, Recommencer, curseur (`Slider`), cinq pastilles de vitesse, « Direct ». Cibles ≥ 48 px de haut, texte ≥ 24 px (NFR lisibilité, sujet de J7 mais tenu ici), budget de la rangée du bas ≤ 140 px (`replayWidth` peut passer de 340 à 480 px si la rangée le permet à 1920 × 1080 : arbitré à la capture). `StageBar` : `BlocBuilder<ReplayBloc>` affiche « Acte 4 · Rejeu » (texte seul, non cliquable) en état Rejeu.
- **Page** : `GenesisCanvasPage` construit le routeur sur `_source.events`, le journal, `ReplayBloc` ; `_gate.attach(router.events)` (mode vivant) ; `CanvasActionScope.enabled`, `startEnabled` = « pas en rejeu » (les deux notions : `_scenarioMode` statique de 000, et `ReplayActive` dynamique). Ordre de fermeture de la page : `ReplayBloc` puis lecteur avant le routeur, le routeur avant le gate.

## Références
- `product/architecture/replay.md` (lecteur, horloge virtuelle, seek) ; `product/architecture/frontend-screen.md` ; `pdr-0066`.
- Notes `knowledge/` : [genui-a2ui-messages], [genui-multiple-surfaces], [genui-test-surface-controller], [test-mock-boundaries-only], [arch-bloc-no-cubit].

## Risques
- **Recréation de surfaces au seek** (même `surfaceId` après `deleteSurface`) → `T05` sonde d'abord (genui 0.10.4) ; repli : nouvel `SurfaceController` à chaque seek est écarté (casse le rendu), on reste sur la remise à vide comme 007.
- **Course entre un message vivant et le passage en rejeu** → décision au niveau du routeur, synchrone, dans l'ordre du flux ; test de course (message vivant pendant `enter()`).
- **Validateur à état** : `gate.reset()` doit précéder toute réinjection, de façon synchrone (comme A4a de 007) → test : seek arrière puis avant ne produit aucun `existing_surface`.
- **Minuteurs** : le lecteur n'a jamais deux minuteurs actifs ; `dispose` annule ; tests avec horloge virtuelle (aucun `Future.delayed` réel).
- **Débordement de la zone Rejeu** (cinq pastilles + curseur dans 340 px × 140 px) → test de widget à 1920 × 1080 sans `RenderFlex overflow`, puis capture `app-smoke`.
- **Régression du rejeu scripté de 000** (`GENESIS_SCENARIO`, utilisé par `app-smoke.sh`) → les tests `loop_harness` restent verts à chaque commit.
