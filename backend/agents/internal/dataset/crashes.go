package dataset

import (
	"fmt"
	"slices"
	"strings"
)

// MaxTopCrashes est le nombre maximal de lignes de la liste des crashs (fiche
// dataset.md, « Liste des crashs » : top 5).
const MaxTopCrashes = 5

// Crash est une ligne de la liste des crashs de la version cible sur 7 jours.
// Volume = occurrences ; Sessions = sessions distinctes touchées. Le rang n'est
// pas stocké : il dépend du filtre et se calcule à l'affichage (builder).
type Crash struct {
	Label    string `json:"label"`
	Platform string `json:"platform"`
	Volume   int    `json:"volume"`
	Sessions int    `json:"sessions"`
}

// TopCrashes renvoie les crashs les plus volumineux de la version cible, dans
// l'ordre décroissant de volume. platform "" = global ; sinon seules les lignes
// de cette plateforme sont gardées, sans renumérotation. limit va de 1 à
// MaxTopCrashes ; moins de lignes peuvent être renvoyées si le filtre en laisse
// moins. La liste ne porte que la version cible : toute autre version est une
// erreur. Le résultat est une copie.
func (d Dataset) TopCrashes(version, platform string, limit int) ([]Crash, error) {
	if version != d.TargetVersion {
		return nil, fmt.Errorf("liste des crashs indisponible pour la version %q (seule la version %q en porte)", version, d.TargetVersion)
	}
	if limit < 1 || limit > MaxTopCrashes {
		return nil, fmt.Errorf("nombre de crashs %d hors de 1 à %d", limit, MaxTopCrashes)
	}
	if platform != "" && !d.knownPlatform(platform) {
		return nil, fmt.Errorf("plateforme inconnue %q pour la liste des crashs", platform)
	}
	out := make([]Crash, 0, limit)
	for _, c := range d.CrashRows {
		if platform != "" && c.Platform != platform {
			continue
		}
		if len(out) == limit {
			break
		}
		out = append(out, c)
	}
	return out, nil
}

// knownPlatform dit si la plateforme figure dans les lignes de sessions.
func (d Dataset) knownPlatform(platform string) bool {
	return slices.ContainsFunc(d.Rows, func(r Row) bool { return r.Platform == platform })
}

// validateCrashes contrôle la cohérence de la liste des crashs (fiche, § Contrôles
// de cohérence) : 1 à 5 lignes, libellé non vide, plateforme connue, volume
// strictement positif, sessions touchées ≤ volume, volumes décroissants.
func (d Dataset) validateCrashes() error {
	if n := len(d.CrashRows); n < 1 || n > MaxTopCrashes {
		return fmt.Errorf("jeu de données embarqué invalide : %d crashs, attendu 1 à %d", n, MaxTopCrashes)
	}
	for i, c := range d.CrashRows {
		switch {
		case strings.TrimSpace(c.Label) == "":
			return fmt.Errorf("jeu de données embarqué invalide : crash %d sans libellé", i+1)
		case !d.knownPlatform(c.Platform):
			return fmt.Errorf("jeu de données embarqué invalide : crash %d, plateforme inconnue %q", i+1, c.Platform)
		case c.Volume <= 0:
			return fmt.Errorf("jeu de données embarqué invalide : crash %d, volume %d non positif", i+1, c.Volume)
		case c.Sessions < 0 || c.Sessions > c.Volume:
			return fmt.Errorf("jeu de données embarqué invalide : crash %d, sessions touchées %d hors de 0 à %d (volume)", i+1, c.Sessions, c.Volume)
		case i > 0 && c.Volume > d.CrashRows[i-1].Volume:
			return fmt.Errorf("jeu de données embarqué invalide : crash %d, ordre non décroissant par volume", i+1)
		}
	}
	return nil
}
