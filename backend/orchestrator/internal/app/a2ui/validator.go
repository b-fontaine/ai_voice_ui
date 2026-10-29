// Package a2ui valide les messages A2UI v0.9 produits par les agents distants
// avant de les relayer à l'application (A3 du plan 004). Le validateur est sans
// état ; le registre de surfaces porte les règles qui dépendent de la session.
package a2ui

import (
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
)

// Kind est le type d'opération d'un message A2UI.
type Kind string

// Opérations A2UI v0.9 acceptées.
const (
	CreateSurface    Kind = "createSurface"
	UpdateComponents Kind = "updateComponents"
	UpdateDataModel  Kind = "updateDataModel"
	DeleteSurface    Kind = "deleteSurface"
)

// Codes d'erreur fermés : aucun texte brut du fournisseur n'est renvoyé.
const (
	CodeBadVersion          = "bad_version"
	CodeBadOperation        = "bad_operation"
	CodeTooLarge            = "too_large"
	CodeTooDeep             = "too_deep"
	CodeBadSurfaceID        = "bad_surface_id"
	CodeBadCatalog          = "bad_catalog"
	CodeBadComponentCount   = "bad_component_count"
	CodeDuplicateID         = "duplicate_component_id"
	CodeBadComponent        = "bad_component"
	CodeComponentNotAllowed = "component_not_allowed"
	CodeBadChildren         = "bad_children"
	CodeBadPointer          = "bad_pointer"
	CodeSurfaceExists       = "surface_exists"
	CodeSurfaceLimit        = "surface_limit"
	CodeUnknownSurface      = "unknown_surface"
	CodeForeignSurface      = "foreign_surface"
	CodeComponentCap        = "component_cap"
	CodeMessageCap          = "message_cap"
	CodeIncompleteSurface   = "incomplete_surface"
)

// ValidationError est l'erreur typée du validateur et du registre.
type ValidationError struct {
	Code   string
	Detail string
}

func (e *ValidationError) Error() string {
	return "a2ui: " + e.Code + ": " + e.Detail
}

func fail(code, format string, args ...any) error {
	return &ValidationError{Code: code, Detail: fmt.Sprintf(format, args...)}
}

// Options configure le validateur ; toutes les valeurs sont injectées.
type Options struct {
	CatalogID              string
	Components             []string
	MaxMessageBytes        int
	MaxDepth               int
	MaxComponentsPerUpdate int
}

// Operation est le résultat d'une validation réussie. Elle ne partage aucune
// mémoire avec le message validé.
type Operation struct {
	Kind           Kind
	SurfaceID      string
	ComponentIDs   []string
	Children       map[string][]string
	RootPresent    bool
	ComponentCount int
}

// Validator vérifie un message à la fois, sans état.
type Validator struct {
	opts    Options
	allowed map[string]struct{}
}

// NewValidator valide les options et construit le validateur.
func NewValidator(o Options) (*Validator, error) {
	if o.CatalogID == "" {
		return nil, errors.New("a2ui: CatalogID vide")
	}
	if len(o.Components) == 0 {
		return nil, errors.New("a2ui: Components vide")
	}
	if o.MaxMessageBytes <= 0 || o.MaxDepth <= 0 || o.MaxComponentsPerUpdate <= 0 {
		return nil, errors.New("a2ui: limites à renseigner (> 0)")
	}
	allowed := make(map[string]struct{}, len(o.Components))
	for _, c := range o.Components {
		allowed[c] = struct{}{}
	}
	o.Components = append([]string(nil), o.Components...)
	return &Validator{opts: o, allowed: allowed}, nil
}

var surfaceIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)

var operations = []Kind{CreateSurface, UpdateComponents, UpdateDataModel, DeleteSurface}

// Validate contrôle msg sans jamais le modifier.
func (v *Validator) Validate(msg map[string]any) (Operation, error) {
	if depth(msg, v.opts.MaxDepth+1) > v.opts.MaxDepth {
		return Operation{}, fail(CodeTooDeep, "profondeur supérieure à %d", v.opts.MaxDepth)
	}
	raw, err := json.Marshal(msg)
	if err != nil {
		return Operation{}, fail(CodeBadOperation, "message non sérialisable")
	}
	if len(raw) > v.opts.MaxMessageBytes {
		return Operation{}, fail(CodeTooLarge, "%d octets (max %d)", len(raw), v.opts.MaxMessageBytes)
	}
	if ver, _ := msg["version"].(string); ver != "v0.9" {
		return Operation{}, fail(CodeBadVersion, "version attendue v0.9")
	}
	var kind Kind
	for k := range msg {
		if k == "version" {
			continue
		}
		known := false
		for _, o := range operations {
			if Kind(k) == o {
				known = true
			}
		}
		if !known || kind != "" {
			return Operation{}, fail(CodeBadOperation, "clé de premier niveau %q non admise ou opération multiple", k)
		}
		kind = Kind(k)
	}
	if kind == "" {
		return Operation{}, fail(CodeBadOperation, "aucune opération")
	}
	body, ok := msg[string(kind)].(map[string]any)
	if !ok {
		return Operation{}, fail(CodeBadOperation, "corps de %s invalide", kind)
	}
	sid, _ := body["surfaceId"].(string)
	if !surfaceIDPattern.MatchString(sid) {
		return Operation{}, fail(CodeBadSurfaceID, "surfaceId invalide")
	}
	op := Operation{Kind: kind, SurfaceID: sid}
	switch kind {
	case CreateSurface:
		if cid, _ := body["catalogId"].(string); cid != v.opts.CatalogID {
			return Operation{}, fail(CodeBadCatalog, "catalogId inattendu")
		}
		if sdm, present := body["sendDataModel"]; present {
			if _, isBool := sdm.(bool); !isBool {
				return Operation{}, fail(CodeBadOperation, "sendDataModel doit être booléen")
			}
		}
	case UpdateComponents:
		if err := v.validateComponents(body, &op); err != nil {
			return Operation{}, err
		}
	case UpdateDataModel:
		if p, present := body["path"]; present {
			s, isStr := p.(string)
			if !isStr || !validPointer(s) {
				return Operation{}, fail(CodeBadPointer, "path n'est pas un JSON Pointer valide")
			}
		}
	}
	return op, nil
}

func (v *Validator) validateComponents(body map[string]any, op *Operation) error {
	list, _ := body["components"].([]any)
	if len(list) < 1 || len(list) > v.opts.MaxComponentsPerUpdate {
		return fail(CodeBadComponentCount, "%d composants (1 à %d attendus)", len(list), v.opts.MaxComponentsPerUpdate)
	}
	seen := make(map[string]struct{}, len(list))
	op.Children = map[string][]string{}
	for _, item := range list {
		c, ok := item.(map[string]any)
		if !ok {
			return fail(CodeBadComponent, "composant invalide")
		}
		id, _ := c["id"].(string)
		if id == "" {
			return fail(CodeBadComponent, "id de composant manquant")
		}
		if _, dup := seen[id]; dup {
			return fail(CodeDuplicateID, "id dupliqué")
		}
		seen[id] = struct{}{}
		name, _ := c["component"].(string)
		if _, allowed := v.allowed[name]; !allowed {
			return fail(CodeComponentNotAllowed, "composant hors liste blanche")
		}
		refs, err := childRefs(c)
		if err != nil {
			return err
		}
		if len(refs) > 0 {
			op.Children[id] = refs
		}
		op.ComponentIDs = append(op.ComponentIDs, id)
		if id == "root" {
			op.RootPresent = true
		}
	}
	op.ComponentCount = len(op.ComponentIDs)
	return nil
}

// childRefs extrait les identifiants référencés par child/children.
func childRefs(c map[string]any) ([]string, error) {
	var refs []string
	if ch, present := c["child"]; present {
		s, ok := ch.(string)
		if !ok || s == "" {
			return nil, fail(CodeBadChildren, "child doit être un identifiant")
		}
		refs = append(refs, s)
	}
	ch, present := c["children"]
	if !present {
		return refs, nil
	}
	switch t := ch.(type) {
	case []any:
		for _, e := range t {
			s, ok := e.(string)
			if !ok || s == "" {
				return nil, fail(CodeBadChildren, "children doit contenir des identifiants")
			}
			refs = append(refs, s)
		}
	case map[string]any:
		cid, ok1 := t["componentId"].(string)
		_, ok2 := t["path"].(string)
		if !ok1 || !ok2 || cid == "" {
			return nil, fail(CodeBadChildren, "gabarit {componentId,path} incomplet")
		}
		refs = append(refs, cid)
	default:
		return nil, fail(CodeBadChildren, "children invalide")
	}
	return refs, nil
}

// validPointer vérifie un JSON Pointer (RFC 6901) ; la chaîne vide est valide.
func validPointer(p string) bool {
	if p == "" {
		return true
	}
	if !strings.HasPrefix(p, "/") {
		return false
	}
	for i := 0; i < len(p); i++ {
		if p[i] == '~' && (i+1 >= len(p) || (p[i+1] != '0' && p[i+1] != '1')) {
			return false
		}
	}
	return true
}

// depth renvoie la profondeur JSON de x, en s'arrêtant dès que limit est atteint.
func depth(x any, limit int) int {
	if limit <= 0 {
		return 0
	}
	max := 0
	switch t := x.(type) {
	case map[string]any:
		max = 1
		for _, e := range t {
			if d := 1 + depth(e, limit-1); d > max {
				max = d
			}
		}
	case []any:
		max = 1
		for _, e := range t {
			if d := 1 + depth(e, limit-1); d > max {
				max = d
			}
		}
	}
	return max
}
