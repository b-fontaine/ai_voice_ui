package a2ui_test

import (
	"errors"
	"fmt"
	"strings"
	"testing"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/app/a2ui"
)

// newGenesisValidator : catalogue fermé genesis, propriétés admises id, component, data.
func newGenesisValidator(t *testing.T) *a2ui.Validator {
	t.Helper()
	v, err := a2ui.NewValidator(a2ui.Options{
		CatalogID:              genesisTestCatalogID,
		Components:             genesisComponents,
		AllowedProps:           []string{"id", "component", "data"},
		BindingProps:           []string{"data"},
		MaxMessageBytes:        64 * 1024,
		MaxDepth:               16,
		MaxComponentsPerUpdate: 50,
	})
	if err != nil {
		t.Fatalf("NewValidator: %v", err)
	}
	return v
}

func updateWith(component string) string {
	return `{"version":"v0.9","updateComponents":{"surfaceId":"kpi","components":[` + component + `]}}`
}

func requireCode(t *testing.T, err error, code string) {
	t.Helper()
	var ve *a2ui.ValidationError
	if !errors.As(err, &ve) || ve.Code != code {
		t.Fatalf("erreur = %v, attendu le code %q", err, code)
	}
}

func TestGenesisAcceptsBoundData(t *testing.T) {
	v := newGenesisValidator(t)
	for name, comp := range map[string]string{
		"liaison":          `{"id":"root","component":"KeyIndicator","data":{"path":"/kpi"}}`,
		"sans data":        `{"id":"root","component":"KeyIndicator"}`,
		"pointeur échappé": `{"id":"root","component":"TrendChart","data":{"path":"/a~1b/c~0d"}}`,
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := v.Validate(parse(t, updateWith(comp))); err != nil {
				t.Fatalf("refusé : %v", err)
			}
		})
	}
}

func TestGenesisRejectsUnknownProperty(t *testing.T) {
	v := newGenesisValidator(t)
	for name, comp := range map[string]string{
		"texte libre":      `{"id":"root","component":"KeyIndicator","text":"99,57 %"}`,
		"style":            `{"id":"root","component":"KeyIndicator","style":{"color":"red"}}`,
		"enfants":          `{"id":"root","component":"KeyIndicator","children":["x"]}`,
		"enfant":           `{"id":"root","component":"KeyIndicator","child":"x"}`,
		"casse différente": `{"id":"root","component":"KeyIndicator","Data":{"path":"/kpi"}}`,
	} {
		t.Run(name, func(t *testing.T) {
			_, err := v.Validate(parse(t, updateWith(comp)))
			requireCode(t, err, a2ui.CodeBadProperty)
			var ve *a2ui.ValidationError
			errors.As(err, &ve)
			// Le message ne reprend jamais la valeur brute de l'agent.
			for _, secret := range []string{"99,57", "red"} {
				if strings.Contains(ve.Error(), secret) {
					t.Fatalf("le message %q contient une valeur brute", ve.Error())
				}
			}
		})
	}
}

func TestGenesisRejectsLiteralData(t *testing.T) {
	v := newGenesisValidator(t)
	long := "/" + strings.Repeat("a", 300)
	for name, data := range map[string]string{
		"littéral":           `{"label":"Sessions sans crash","value":"99,57 %"}`,
		"chaîne":             `"99,57 %"`,
		"nombre":             `99.57`,
		"nul":                `null`,
		"tableau":            `[{"path":"/kpi"}]`,
		"objet vide":         `{}`,
		"path et valeur":     `{"path":"/kpi","value":"99,57 %"}`,
		"path non chaîne":    `{"path":3}`,
		"path relatif":       `{"path":"kpi"}`,
		"path vide":          `{"path":""}`,
		"path trop long":     `{"path":"` + long + `"}`,
		"path avec contrôle": `{"path":"/kpi\u0007"}`,
		"path avec saut":     `{"path":"/kpi\n/x"}`,
		"échappement ~":      `{"path":"/a~2b"}`,
	} {
		t.Run(name, func(t *testing.T) {
			comp := fmt.Sprintf(`{"id":"root","component":"KeyIndicator","data":%s}`, data)
			_, err := v.Validate(parse(t, updateWith(comp)))
			requireCode(t, err, a2ui.CodeBadProperty)
		})
	}
}

// Sans AllowedProps ni BindingProps, le comportement de 004 est inchangé :
// propriétés libres, data littéral accepté.
func TestValidatorWithoutAllowedPropsUnchanged(t *testing.T) {
	v := newValidator(t)
	comp := `{"id":"root","component":"Text","text":"99,57 %","style":{"x":1},"data":{"value":3},"children":["a"]}`
	msg := parse(t, `{"version":"v0.9","updateComponents":{"surfaceId":"s","components":[`+comp+`,{"id":"a","component":"Text","text":"x"}]}}`)
	if _, err := v.Validate(msg); err != nil {
		t.Fatalf("refusé sans AllowedProps : %v", err)
	}
}

func TestNewValidatorRejectsBadPropOptions(t *testing.T) {
	base := a2ui.Options{CatalogID: "c", Components: []string{"Text"}, MaxMessageBytes: 1, MaxDepth: 1, MaxComponentsPerUpdate: 1}
	for name, mod := range map[string]func(*a2ui.Options){
		"liaison sans liste blanche": func(o *a2ui.Options) { o.BindingProps = []string{"data"} },
		"liaison hors liste blanche": func(o *a2ui.Options) { o.AllowedProps = []string{"id"}; o.BindingProps = []string{"data"} },
		"propriété vide":             func(o *a2ui.Options) { o.AllowedProps = []string{"id", ""} },
	} {
		t.Run(name, func(t *testing.T) {
			o := base
			mod(&o)
			if _, err := a2ui.NewValidator(o); err == nil {
				t.Fatal("options refusées attendues")
			}
		})
	}
}

// Les messages de référence du contrat passent avec la liste blanche de propriétés.
func TestGenesisFixturesPassWithAllowedProps(t *testing.T) {
	v := newGenesisValidator(t)
	for _, ex := range genesisExamples {
		for i, msg := range genesisMessages(t, ex.file) {
			if _, err := v.Validate(msg); err != nil {
				t.Fatalf("%s, message %d refusé : %v", ex.file, i+1, err)
			}
		}
	}
}
