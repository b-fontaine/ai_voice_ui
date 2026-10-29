package main

import (
	_ "embed"
	"net/http"
)

//go:embed web/index.html
var indexHTML []byte

// handleIndex sert la page de test (micro du navigateur, annulation d'écho). Elle ne
// contient aucune clé : elle parle uniquement à ce relais, sur 127.0.0.1.
func handleIndex(w http.ResponseWriter, req *http.Request) {
	if req.URL.Path != "/" {
		http.NotFound(w, req)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write(indexHTML)
}
