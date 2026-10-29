package domain

// MaxSessionIDLen est la longueur maximale d'un identifiant de session.
const MaxSessionIDLen = 128

// ValidSessionID indique si id est un identifiant de session acceptable :
// 1 à 128 caractères parmi [A-Za-z0-9_-]. Cette règle protège le journal
// (nom de fichier) et le filtre `?session=` du canal applicatif.
func ValidSessionID(id string) bool {
	if len(id) == 0 || len(id) > MaxSessionIDLen {
		return false
	}
	for i := 0; i < len(id); i++ {
		c := id[i]
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '_', c == '-':
		default:
			return false
		}
	}
	return true
}
