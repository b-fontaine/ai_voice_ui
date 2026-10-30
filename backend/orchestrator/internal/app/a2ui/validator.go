// Package a2ui valide les messages A2UI v0.9 produits par les agents distants
// avant de les relayer à l'application (A3 du plan 004). Le validateur est sans
// état ; le registre de surfaces porte les règles qui dépendent de l'état du canevas.
package a2ui

import (
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

// maxBindingPathRunes borne la longueur du JSON Pointer d'une liaison de données.
const maxBindingPathRunes = 128

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
	CodeBadProperty         = "bad_property"
	CodeSurfaceExists       = "surface_exists"
	CodeSurfaceLimit        = "surface_limit"
	CodeUnknownSurface      = "unknown_surface"
	CodeForeignSurface      = "foreign_surface"
	CodeComponentCap        = "component_cap"
	CodeMessageCap          = "message_cap"
	CodeIncompleteSurface   = "incomplete_surface"
	CodePathNotAllowed      = "path_not_allowed"
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
	// AllowedProps : propriétés qu'un composant peut porter (liste blanche,
	// `id` et `component` comprises). Vide : aucun contrôle des propriétés.
	AllowedProps []string
	// BindingProps : propriétés qui ne peuvent être qu'une liaison
	// {"path": "<JSON Pointer>"}, jamais une valeur littérale. Sous-ensemble de
	// AllowedProps ; vide : aucune liaison imposée.
	BindingProps []string
	// WritableSubPaths : sous-chemins qu'un `updateDataModel` peut écrire en plus
	// de l'objet entier de la surface (chemin "/" + surfaceId). Clé = chemin
	// complet (≥ 2 segments, JSON Pointer valide), valeur = type JSON attendu
	// (seul "string" est connu). nil : chemins non contrôlés (comportement de 004) ;
	// non nil mais vide : seul l'objet entier est admis (R4, spec 009).
	WritableSubPaths map[string]string
}

// ParseWritableSubPaths lit la valeur de A2UI_WRITABLE_SUBPATHS : des entrées
// `chemin:type` séparées par des virgules. Valeur vide : nil (non configurée).
// L'erreur ne reproduit jamais la valeur.
func ParseWritableSubPaths(raw string) (map[string]string, error) {
	var out map[string]string
	for _, e := range strings.Split(raw, ",") {
		if e = strings.TrimSpace(e); e == "" {
			continue
		}
		i := strings.LastIndex(e, ":")
		if i < 0 {
			return nil, errors.New("a2ui: entrée de sous-chemins inscriptibles sans type")
		}
		path, typ := strings.TrimSpace(e[:i]), strings.TrimSpace(e[i+1:])
		if err := checkWritableSubPath(path, typ); err != nil {
			return nil, err
		}
		if out == nil {
			out = map[string]string{}
		}
		if _, dup := out[path]; dup {
			return nil, errors.New("a2ui: sous-chemin inscriptible en double")
		}
		out[path] = typ
	}
	return out, nil
}

func checkWritableSubPath(path, typ string) error {
	if !strings.HasPrefix(path, "/") || !validPointer(path) || len(strings.Split(path, "/")) < 3 {
		return errors.New("a2ui: sous-chemin inscriptible invalide (JSON Pointer d'au moins deux segments attendu)")
	}
	if typ != "string" {
		return errors.New("a2ui: type de sous-chemin inscriptible inconnu (string attendu)")
	}
	return nil
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
	props   map[string]struct{} // nil : propriétés non contrôlées
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
	o.AllowedProps = append([]string(nil), o.AllowedProps...)
	o.BindingProps = append([]string(nil), o.BindingProps...)
	if o.WritableSubPaths != nil {
		sub := make(map[string]string, len(o.WritableSubPaths))
		for p, typ := range o.WritableSubPaths {
			if err := checkWritableSubPath(p, typ); err != nil {
				return nil, err
			}
			sub[p] = typ
		}
		o.WritableSubPaths = sub
	}
	var props map[string]struct{}
	if len(o.AllowedProps) > 0 {
		props = make(map[string]struct{}, len(o.AllowedProps))
		for _, p := range o.AllowedProps {
			if p == "" {
				return nil, errors.New("a2ui: AllowedProps contient un nom vide")
			}
			props[p] = struct{}{}
		}
	}
	for _, p := range o.BindingProps {
		if _, ok := props[p]; !ok {
			return nil, errors.New("a2ui: BindingProps doit être inclus dans AllowedProps")
		}
	}
	return &Validator{opts: o, allowed: allowed, props: props}, nil
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
		if err := v.checkWritablePath(sid, body); err != nil {
			return Operation{}, err
		}
	}
	return op, nil
}

// checkWritablePath applique R4 : l'objet entier de la surface ("/" + sid) ou
// un sous-chemin déclaré de cette surface, avec le type déclaré. Sans effet si
// WritableSubPaths n'est pas configurée. Absent, le chemin vaut la racine « / »
// du data model et est donc refusé.
func (v *Validator) checkWritablePath(sid string, body map[string]any) error {
	if v.opts.WritableSubPaths == nil {
		return nil
	}
	path, _ := body["path"].(string)
	if path == "/"+sid {
		return nil
	}
	typ, declared := v.opts.WritableSubPaths[path]
	if !declared || !strings.HasPrefix(path, "/"+sid+"/") {
		return fail(CodePathNotAllowed, "chemin d'écriture non admis")
	}
	if typ == "string" {
		if _, ok := body["value"].(string); !ok {
			return fail(CodePathNotAllowed, "type de valeur non admis pour ce chemin")
		}
	}
	return nil
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
		if err := v.validateProps(c); err != nil {
			return err
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

// validateProps applique la liste blanche de propriétés et les liaisons
// imposées. Les messages n'incluent jamais le nom ni la valeur reçus.
func (v *Validator) validateProps(c map[string]any) error {
	if v.props == nil {
		return nil
	}
	for k := range c {
		if _, ok := v.props[k]; !ok {
			return fail(CodeBadProperty, "propriété hors liste blanche")
		}
	}
	for _, k := range v.opts.BindingProps {
		val, present := c[k]
		if !present {
			continue
		}
		if !validBinding(val) {
			return fail(CodeBadProperty, "une propriété de données doit être une liaison {path}")
		}
	}
	return nil
}

// validBinding vérifie exactement {"path": "<JSON Pointer>"} : une seule clé,
// pointeur non vide commençant par « / », borné, sans caractère de contrôle.
func validBinding(val any) bool {
	m, ok := val.(map[string]any)
	if !ok || len(m) != 1 {
		return false
	}
	path, ok := m["path"].(string)
	if !ok || !strings.HasPrefix(path, "/") || utf8.RuneCountInString(path) > maxBindingPathRunes || !validPointer(path) {
		return false
	}
	for _, r := range path {
		if unicode.IsControl(r) || unicode.Is(unicode.Cf, r) {
			return false
		}
	}
	return true
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
