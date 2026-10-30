package a2ui_test

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
)

// Parité avec le client Dart (spec 007, A5c) : les fixtures négatives partagées
// `contracts/a2ui/genesis/v1/invalid/*.jsonl` sont rejouées sur un validateur
// NEUF configuré comme en production. Tous les messages sont acceptés sauf le
// dernier, refusé avec le code consigné dans expected.json.

func newProductionLikeValidator(t *testing.T) *a2ui.Validator {
	t.Helper()
	v, err := a2ui.NewValidator(a2ui.Options{
		CatalogID:              genesisTestCatalogID,
		Components:             genesisComponents,
		MaxMessageBytes:        64 << 10, // a2uiMaxMessageBytes (bootstrap)
		MaxDepth:               16,
		MaxComponentsPerUpdate: 100,
		AllowedProps:           []string{"id", "component", "data"},
		BindingProps:           []string{"data"},
	})
	if err != nil {
		t.Fatal(err)
	}
	return v
}

// invalidMessages charge une fixture négative (catalogId remplacé) : une ligne = un message.
func invalidMessages(t *testing.T, file string) []map[string]any {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join(genesisContractDir(t), "invalid", file))
	if err != nil {
		t.Fatalf("fixture illisible : %v", err)
	}
	raw = bytes.ReplaceAll(raw, []byte("${CATALOG_ID}"), []byte(genesisTestCatalogID))
	var out []map[string]any
	sc := bufio.NewScanner(bytes.NewReader(raw))
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("%s : ligne JSON invalide : %v", file, err)
		}
		out = append(out, m)
	}
	if err := sc.Err(); err != nil {
		t.Fatal(err)
	}
	return out
}

func TestGenesisInvalidFixturesAreRejectedWithExpectedCode(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join(genesisContractDir(t), "invalid", "expected.json"))
	if err != nil {
		t.Fatalf("expected.json illisible : %v", err)
	}
	var expected map[string]string
	if err := json.Unmarshal(raw, &expected); err != nil {
		t.Fatal(err)
	}
	files, err := filepath.Glob(filepath.Join(genesisContractDir(t), "invalid", "*.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	if len(files) == 0 || len(files) != len(expected) {
		t.Fatalf("%d fixture(s) .jsonl pour %d entrée(s) de expected.json", len(files), len(expected))
	}
	for _, path := range files {
		file := filepath.Base(path)
		code, ok := expected[file]
		if !ok {
			t.Errorf("%s : absent de expected.json", file)
			continue
		}
		t.Run(file, func(t *testing.T) {
			msgs := invalidMessages(t, file)
			if len(msgs) == 0 {
				t.Fatal("fixture vide")
			}
			v := newProductionLikeValidator(t)
			reg, err := a2ui.NewRegistry(a2ui.Limits{MaxSurfaces: 6, MaxComponentsPerSurface: 200, MaxMessagesPerTask: 64})
			if err != nil {
				t.Fatal(err)
			}
			for i, msg := range msgs {
				op, err := v.Validate(msg)
				if err == nil {
					err = reg.Apply("agent", "task-1", op)
				}
				last := i == len(msgs)-1
				if !last {
					if err != nil {
						t.Fatalf("message %d/%d refusé (%v), seul le dernier doit l'être", i+1, len(msgs), err)
					}
					continue
				}
				var ve *a2ui.ValidationError
				if !errors.As(err, &ve) {
					t.Fatalf("dernier message : erreur de validation attendue (code %q), obtenu %v", code, err)
				}
				if ve.Code != code {
					t.Fatalf("dernier message : code %q, attendu %q (%s)", ve.Code, code, ve.Detail)
				}
			}
		})
	}
}
