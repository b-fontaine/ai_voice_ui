package main

import (
	"bytes"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/dataset"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/kit"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/llmcompose"
	"github.com/b-fontaine/ai_voice_ui/backend/agents/internal/quality"
)

const catalog = "https://example.test/genesis/catalog.json"

func settings(t *testing.T, url string, timeout time.Duration) kit.Settings {
	t.Helper()
	ds, err := dataset.Load()
	if err != nil {
		t.Fatal(err)
	}
	s := kit.Settings{ComposerLLMURL: url, ComposerTimeout: timeout}
	s.CatalogID, s.Dataset = catalog, ds
	return s
}

// Sans COMPOSER_LLM_URL : composeur déterministe de Qualité, aucun client du modèle.
func TestWithoutGatewayTheComposerIsDeterministic(t *testing.T) {
	c, err := newComposer(settings(t, "", 0), slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := c.(*quality.Composer); !ok {
		t.Errorf("composeur %T, attendu *quality.Composer", c)
	}
}

// Avec la passerelle : le décorateur LLM autour du déterministe.
func TestWithGatewayTheComposerIsTheLLMDecorator(t *testing.T) {
	c, err := newComposer(settings(t, "http://172.30.77.10:8081/v1/complete", 5*time.Second), slog.Default())
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := c.(*llmcompose.Composer); !ok {
		t.Errorf("composeur %T, attendu *llmcompose.Composer", c)
	}
}

// Une URL refusée par le client est une erreur de configuration sans la valeur.
func TestGatewayErrorNeverEchoesTheURL(t *testing.T) {
	var logs bytes.Buffer
	_, err := newComposer(settings(t, "http://hote-secret:1/autre", 5*time.Second), slog.New(slog.NewTextHandler(&logs, nil)))
	if err == nil {
		t.Fatal("URL à chemin non conforme acceptée")
	}
	if strings.Contains(err.Error(), "hote-secret") || strings.Contains(logs.String(), "hote-secret") {
		t.Errorf("la valeur de configuration fuit : %v / %s", err, logs.String())
	}
}
