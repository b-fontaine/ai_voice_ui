package main

import (
	"log/slog"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

// profileName est le profil d'exemples embarqué de llmcompose pour cet agent.
const profileName = "quality"

// newComposer est la fabrique du composeur de l'agent Qualité (seul le binaire assemble
// llmcompose et quality). Sans COMPOSER_LLM_URL : le composeur déterministe. Avec : le
// décorateur llmcompose, dont le repli est ce même composeur déterministe.
func newComposer(s kit.Settings, log *slog.Logger) (kit.Composer, error) {
	deterministic := quality.NewComposer(s.CatalogID)
	if s.ComposerLLMURL == "" {
		return deterministic, nil
	}
	validator, err := llmcompose.NewValidator(quality.ComposerProfile(s.Dataset))
	if err != nil {
		return nil, err
	}
	examples, err := llmcompose.LoadExamples(profileName)
	if err != nil {
		return nil, err
	}
	prompt, err := llmcompose.NewPrompt(validator, examples)
	if err != nil {
		return nil, err
	}
	client, err := llmcompose.NewClient(s.ComposerLLMURL, s.ComposerTimeout)
	if err != nil {
		return nil, err
	}
	return llmcompose.NewComposer(llmcompose.Config{
		Validator:    validator,
		Completer:    client,
		Fallback:     deterministic,
		CatalogID:    s.CatalogID,
		Instructions: prompt.Instructions(),
		Log:          log,
	})
}
