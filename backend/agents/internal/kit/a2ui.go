package kit

import "slices"

// SurfaceMessages renvoie les messages A2UI v0.9 d'une surface. Si id n'est pas dans
// active : createSurface, updateComponents (un seul composant `root` lié à path) et
// updateDataModel (value à path), dans cet ordre (G4). Si la surface est déjà ouverte
// chez le client, son composant `root` est inchangé : seul updateDataModel est émis
// (pdr-0064, D1).
func SurfaceMessages(catalogID string, active []string, id, component, path string, value map[string]any) []map[string]any {
	data := map[string]any{"version": "v0.9", "updateDataModel": map[string]any{
		"surfaceId": id, "path": path, "value": value,
	}}
	if slices.Contains(active, id) {
		return []map[string]any{data}
	}
	return append(SurfaceSkeleton(catalogID, active, id, component, path), data)
}

// SurfaceSkeleton renvoie le squelette d'une surface, c'est-à-dire les deux premiers messages
// de SurfaceMessages (createSurface puis updateComponents), ou rien si la surface est déjà
// ouverte chez le client. Il permet d'afficher la surface avant d'avoir ses données (RG-03).
func SurfaceSkeleton(catalogID string, active []string, id, component, path string) []map[string]any {
	if slices.Contains(active, id) {
		return nil
	}
	return []map[string]any{
		{"version": "v0.9", "createSurface": map[string]any{
			"surfaceId": id, "catalogId": catalogID, "sendDataModel": false,
		}},
		{"version": "v0.9", "updateComponents": map[string]any{
			"surfaceId": id,
			"components": []any{
				map[string]any{"id": "root", "component": component, "data": map[string]any{"path": path}},
			},
		}},
	}
}
