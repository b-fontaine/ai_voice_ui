// Package quality est la racine du module de l'agent A2A « Qualité » de
// Genesis Canvas (fonctionnalité 004) : il répond en A2A (a2a-go v2, natif
// v1.0) avec une surface A2UI v0.9 et un résumé factuel tirés d'un jeu de
// données figé. Le code vit sous internal/ ; ce fichier garantit que
// `go vet ./...` et `go test ./...` trouvent un paquet quand les tests
// d'acceptation (build tag acceptance) sont exclus.
package quality
