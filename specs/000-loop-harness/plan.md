# 000 — Plan technique

## Où
| Pile | Paquet | Couche ou slice | Contenu |
|---|---|---|---|
| Flutter | `pubspec.yaml` racine | workspace pub | membres : `apps/genesis_canvas`, `packages/features/canvas`, `packages/shared/core` |
| Flutter | `apps/genesis_canvas` | `app/{di,bootstrap,config}`, `pages/genesis_canvas` | `main.dart`, racine de composition get_it/injectable, lecture de `GENESIS_SCENARIO` / `GENESIS_SNAPSHOT` (configuration injectée) ; `SnapshotService` (`app/bootstrap/`, `RepaintBoundary.toImage` → PNG, puis sortie) actif seulement en debug et si la variable est fournie, consommé par la page via l'interface `CaptureService` |
| Flutter | `packages/features/canvas` | `model/` (Bloc), `ui/`, `api/` | `CanvasBloc` (events/states sealed, transformer explicite) qui applique des messages A2UI au `SurfaceController` ; widget `CanvasBoard` (grille tenue par l'app, pdr-0015) |
| Flutter | `packages/shared/core` | `debug/` | `A2uiReplaySource` (lit un JSONL de messages v0.9 avec délais relatifs) ; typedef `ExitHandler` (Dart pur) |
| Fixture | `apps/genesis_canvas/assets/replays/act1-replay.jsonl` | — | 3 à 5 messages v0.9 (createSurface, updateComponents, updateDataModel) tirés de `product/functional/dataset.md` |

## Contrats
- Message A2UI : `{"version":"v0.9", …}` exactement ([genui-a2ui-messages]) ; catalogue de base genui (`BasicCatalogItems.asCatalog()`).
- Ligne de rejeu : `{"t_ms": <délai depuis le début>, "message": {…}}`.
- `SnapshotService` : écrit le PNG puis `exit(0)` ; en cas d'erreur, message sur stderr et `exit(1)`.

## Références
- `product/architecture/frontend.md` (arborescence, slices) ; `knowledge/` : [genui-architecture], [genui-test-surface-controller], [arch-pub-workspaces], [di-no-service-locator], [bloc-event-transformers], [test-bdd-widget-test].
- Fait vérifié le 2026-10-29 : genui 0.10.4 rend une surface v0.9 sous Linux une fois GStreamer installé (SP-10, [genui-overview]).

## Risques
- Rendu sous Xvfb : GDK en X11 (`GDK_BACKEND=x11`) ; Impeller OpenGLES sous Xvfb à vérifier → repli `--no-enable-impeller` documenté dans `app-smoke.sh` si besoin.
