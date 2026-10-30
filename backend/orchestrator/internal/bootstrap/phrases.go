package bootstrap

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"errors"
	"os"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/orchestrate"
	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/voice"
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
	PartialFailure  string `json:"partial_failure"`
	ResultTemplate  string `json:"result_template"`
	// Action de l'interface (009) : confirmation et échec.
	ActionResultTemplate string `json:"action_result_template"`
	ActionFailure        string `json:"action_failure"`
	// Consignes de dernier recours d'une annonce hors délégation (textes fixes) :
	// confirmation d'une décision, constat d'un échec.
	AnnounceInstructionDone   string `json:"announce_instruction_done"`
	AnnounceInstructionFailed string `json:"announce_instruction_failed"`
}

// loadPhrases lit le fichier de phrases (ou les phrases embarquées si path est
// vide). Les erreurs n'exposent jamais le contenu du fichier.
func loadPhrases(path string) (orchestrate.Phrases, voice.Phrases, error) {
	raw := defaultPhrases
	if path != "" {
		var err error
		if raw, err = os.ReadFile(path); err != nil {
			return orchestrate.Phrases{}, voice.Phrases{}, errors.New("VOICE_PHRASES_FILE : fichier illisible")
		}
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	var f phrasesFile
	if err := dec.Decode(&f); err != nil {
		return orchestrate.Phrases{}, voice.Phrases{}, errors.New("VOICE_PHRASES_FILE : JSON invalide (objet avec generic, failure, failure_rejected, no_summary, queue_full, no_request, no_agent, out_of_catalog, partial_failure, result_template, action_result_template, action_failure, announce_instruction_done, announce_instruction_failed attendu)")
	}
	p := orchestrate.Phrases{
		Generic: f.Generic, Failure: f.Failure, FailureRejected: f.FailureRejected, NoSummary: f.NoSummary, QueueFull: f.QueueFull,
		NoRequest: f.NoRequest, NoAgent: f.NoAgent, OutOfCatalog: f.OutOfCatalog, PartialFailure: f.PartialFailure, ResultTemplate: f.ResultTemplate,
		ActionResultTemplate: f.ActionResultTemplate, ActionFailure: f.ActionFailure,
	}
	vp := voice.Phrases{AnnounceDone: f.AnnounceInstructionDone, AnnounceFailed: f.AnnounceInstructionFailed}
	for key, v := range map[string]string{"failure_rejected": f.FailureRejected, "no_summary": f.NoSummary, "out_of_catalog": f.OutOfCatalog, "partial_failure": f.PartialFailure,
		"action_result_template": f.ActionResultTemplate, "action_failure": f.ActionFailure,
		"announce_instruction_done": f.AnnounceInstructionDone, "announce_instruction_failed": f.AnnounceInstructionFailed} {
		if v == "" {
			return orchestrate.Phrases{}, voice.Phrases{}, errors.New("VOICE_PHRASES_FILE : clé " + key + " requise")
		}
	}
	if err := p.Validate(); err != nil || vp.Validate() != nil {
		return orchestrate.Phrases{}, voice.Phrases{}, errors.New("VOICE_PHRASES_FILE : phrases invalides (toutes non vides et d'au plus 1 000 runes, result_template, partial_failure et action_result_template avec un seul %s chacun, résumé compris sous 1 000 runes)")
	}
	return p, vp, nil
}
