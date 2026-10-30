package kit

import "slices"

// SurfaceMessages renvoie les messages A2UI v0.9 d'une surface : createSurface
// seulement si id n'est pas dans active (surfaces déjà ouvertes chez le client), puis
// updateComponents (un seul composant `root` lié à path) et updateDataModel (value à
// path), dans cet ordre (G4).
func SurfaceMessages(catalogID string, active []string, id, component, path string, value map[string]any) []map[string]any {
	var msgs []map[string]any
	if !slices.Contains(active, id) {
		msgs = append(msgs, map[string]any{"version": "v0.9", "createSurface": map[string]any{
			"surfaceId": id, "catalogId": catalogID, "sendDataModel": false,
		}})
	}
	return append(msgs,
		map[string]any{"version": "v0.9", "updateComponents": map[string]any{
			"surfaceId": id,
			"components": []any{
				map[string]any{"id": "root", "component": component, "data": map[string]any{"path": path}},
			},
		}},
		map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
			"surfaceId": id, "path": path, "value": value,
		}},
	)
}
