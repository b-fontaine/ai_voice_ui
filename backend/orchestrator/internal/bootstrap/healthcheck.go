package bootstrap

import (
	"net"
	"strconv"
)

// HealthcheckURL renvoie l'adresse de /healthz que sonde la sous-commande
// « orchestrator healthcheck » : toujours la boucle locale du conteneur,
// sur le port configuré. Aucun secret n'est requis.
func HealthcheckURL(getenv func(string) string) (string, error) {
	port, err := parseListenPort(getenv)
	if err != nil {
		return "", err
	}
	return "http://" + net.JoinHostPort(defaultListenHost, strconv.Itoa(port)) + "/healthz", nil
}
