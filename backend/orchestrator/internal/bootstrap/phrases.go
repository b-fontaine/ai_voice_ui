package bootstrap

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"errors"
	"os"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/orchestrate"
)

// defaultPhrases sont les commentaires vocaux français embarqués ; ils servent
// quand VOICE_PHRASES_FILE est absent (pdr-0009 : jamais de phrase en dur dans le code).
//
//go:embed config/phrases.fr.json
var defaultPhrases []byte

// phrasesFile est le format JSON du fichier de phrases.
type phrasesFile struct {
	Generic         string `json:"generic"`
	Failure         string `json:"failure"`
	FailureRejected string `json:"failure_rejected"`
	NoSummary       string `json:"no_summary"`
	QueueFull       string `json:"queue_full"`
	NoRequest       string `json:"no_request"`
	NoAgent         string `json:"no_agent"`
	OutOfCatalog    string `json:"out_of_catalog"`
	ResultTemplate  string `json:"result_template"`
}

// loadPhrases lit le fichier de phrases (ou les phrases embarquées si path est
// vide). Les erreurs n'exposent jamais le contenu du fichier.
func loadPhrases(path string) (orchestrate.Phrases, error) {
	raw := defaultPhrases
	if path != "" {
		var err error
		if raw, err = os.ReadFile(path); err != nil {
			return orchestrate.Phrases{}, errors.New("VOICE_PHRASES_FILE : fichier illisible")
		}
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	var f phrasesFile
	if err := dec.Decode(&f); err != nil {
		return orchestrate.Phrases{}, errors.New("VOICE_PHRASES_FILE : JSON invalide (objet avec generic, failure, failure_rejected, no_summary, queue_full, no_request, no_agent, out_of_catalog, result_template attendu)")
	}
	p := orchestrate.Phrases{
		Generic: f.Generic, Failure: f.Failure, FailureRejected: f.FailureRejected, NoSummary: f.NoSummary, QueueFull: f.QueueFull,
		NoRequest: f.NoRequest, NoAgent: f.NoAgent, OutOfCatalog: f.OutOfCatalog, ResultTemplate: f.ResultTemplate,
	}
	for key, v := range map[string]string{"failure_rejected": f.FailureRejected, "no_summary": f.NoSummary, "out_of_catalog": f.OutOfCatalog} {
		if v == "" {
			return orchestrate.Phrases{}, errors.New("VOICE_PHRASES_FILE : clé " + key + " requise")
		}
	}
	if err := p.Validate(); err != nil {
		return orchestrate.Phrases{}, errors.New("VOICE_PHRASES_FILE : phrases invalides (toutes non vides et d'au plus 1 000 runes, result_template avec un seul %s et résumé compris sous 1 000 runes)")
	}
	return p, nil
}
