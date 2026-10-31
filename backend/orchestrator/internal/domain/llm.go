package domain

import "encoding/json"

// LlmRequest est une demande de génération de texte structuré. Instructions
// vient du code d'un agent (de confiance) ; Input porte la demande de
// l'utilisateur (non fiable). Schema est un schéma JSON (objet, strict).
type LlmRequest struct {
	Instructions string
	Input        string
	SchemaName   string
	Schema       json.RawMessage
}

// LlmResult est la sortie JSON du modèle, telle quelle, et les jetons
// facturés (entrée et sortie, raisonnement compris).
type LlmResult struct {
	JSON         json.RawMessage
	InputTokens  int
	OutputTokens int
}
