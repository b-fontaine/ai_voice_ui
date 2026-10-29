package bootstrap

import (
	"errors"
	"net"
	"strconv"
	"strings"
)

// HealthcheckURL renvoie l'adresse de /healthz que sonde la sous-commande
// « orchestrator healthcheck » : toujours la boucle locale du conteneur,
// sur le port configuré. Aucun secret n'est requis.
func HealthcheckURL(getenv func(string) string) (string, error) {
	port := defaultListenPort
	if raw := strings.TrimSpace(getenv("LISTEN_PORT")); raw != "" {
		p, err := strconv.Atoi(raw)
		if err != nil || p < 1 || p > 65535 {
			return "", errors.New("LISTEN_PORT doit être un entier entre 1 et 65535")
		}
		port = p
	}
	return "http://" + net.JoinHostPort(defaultListenHost, strconv.Itoa(port)) + "/healthz", nil
}
