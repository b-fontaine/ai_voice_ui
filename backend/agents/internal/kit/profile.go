package kit

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"regexp"
	"slices"
	"strings"
)

// Skill décrit l'unique compétence publiée dans la carte d'agent. Les tags sont des
// mots entiers français ; les exemples sont des demandes types.
type Skill struct {
	ID       string   `json:"id"`
	Name     string   `json:"name"`
	Tags     []string `json:"tags"`
	Examples []string `json:"examples"`
}

// Texts regroupe les textes d'état terminal renvoyés au client. Ils ne citent aucun
// numéro de jalon.
type Texts struct {
	Rejected string `json:"rejected"`
	Failed   string `json:"failed"`
}

// Profile est l'identité d'un agent, embarquée (go:embed) dans son paquet et chargée
// par LoadProfile. Le noyau n'en connaît aucune valeur.
type Profile struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	ListenPort  int    `json:"listenPort"` // port d'écoute par défaut (127.0.0.1)
	Skill       Skill  `json:"skill"`
	Texts       Texts  `json:"texts"`
}

// acceptsAction indique si le profil déclare le tag `action:<name>`.
func (p Profile) acceptsAction(name string) bool {
	return slices.Contains(p.Skill.Tags, actionTagPrefix+name)
}

// milestone repère un numéro de jalon (« J2 », « J12 ») comme mot entier.
var milestone = regexp.MustCompile(`\bJ[0-9]+\b`)

// LoadProfile décode et valide un profil : champs inconnus, données après le JSON,
// champs obligatoires vides, port hors 1-65535 et numéro de jalon dans un texte sont
// rejetés. Les erreurs citent le champ, jamais sa valeur.
func LoadProfile(data []byte) (Profile, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	var p Profile
	if err := dec.Decode(&p); err != nil {
		return Profile{}, fmt.Errorf("profil illisible : %w", err)
	}
	if _, err := dec.Token(); !errors.Is(err, io.EOF) {
		return Profile{}, errors.New("profil illisible : données après l'objet JSON")
	}
	if err := p.validate(); err != nil {
		return Profile{}, fmt.Errorf("profil invalide : %w", err)
	}
	return p, nil
}

func (p Profile) validate() error {
	blank := func(s string) bool { return strings.TrimSpace(s) == "" }
	switch {
	case blank(p.Name):
		return errors.New("name est obligatoire")
	case blank(p.Description):
		return errors.New("description est obligatoire")
	case p.ListenPort < 1 || p.ListenPort > 65535:
		return errors.New("listenPort doit être compris entre 1 et 65535")
	case blank(p.Skill.ID):
		return errors.New("skill.id est obligatoire")
	case blank(p.Skill.Name):
		return errors.New("skill.name est obligatoire")
	case len(p.Skill.Tags) == 0:
		return errors.New("skill.tags ne peut pas être vide")
	case len(p.Skill.Examples) == 0:
		return errors.New("skill.examples ne peut pas être vide")
	case blank(p.Texts.Rejected):
		return errors.New("texts.rejected est obligatoire")
	case blank(p.Texts.Failed):
		return errors.New("texts.failed est obligatoire")
	}
	for _, t := range p.Skill.Tags {
		if blank(t) {
			return errors.New("skill.tags contient un tag vide")
		}
	}
	for _, e := range p.Skill.Examples {
		if blank(e) {
			return errors.New("skill.examples contient un exemple vide")
		}
	}
	if milestone.MatchString(p.Texts.Rejected) {
		return errors.New("texts.rejected cite un numéro de jalon")
	}
	if milestone.MatchString(p.Texts.Failed) {
		return errors.New("texts.failed cite un numéro de jalon")
	}
	return nil
}
