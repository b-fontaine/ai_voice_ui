// Package a2aclient est l'adaptateur de port.RemoteAgent au-dessus du client
// A2A natif (a2a-go v2, protocole v1.0, JSON-RPC en streaming).
//
// Aucune goroutine n'appartient à l'adaptateur : Send renvoie un itérateur dont
// le travail (carte, connexion, lecture du flux, annulation) se fait dans la
// boucle de l'appelant. La carte est relue à chaque appel de Card : un agent
// redémarré est pris en compte. Send réutilise la carte lue par Card quand
// l'appelant la lui rend (AgentRequest.Card) ; sinon il la lit lui-même.
package a2aclient

import (
	"context"
	"errors"
	"iter"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/a2aproject/a2a-go/v2/a2a"
	sdk "github.com/a2aproject/a2a-go/v2/a2aclient"
	"github.com/a2aproject/a2a-go/v2/a2aclient/agentcard"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// ActiveSurfacesKey est la clé de metadata du message A2A qui porte les surfaces
// actives de l'agent (valeur : []any de chaînes, jamais []string : les metadata
// ne contiennent que map[string]any et []any).
const ActiveSurfacesKey = "genesis/activeSurfaces"

// cancelTimeout borne l'appel CancelTask, émis avec un contexte neuf.
const cancelTimeout = time.Second

// Options configure un Agent.
type Options struct {
	// CardURL est l'URL de la carte d'agent : http ou https uniquement.
	CardURL string
	// Name est le nom d'affichage configuré (facultatif) : il prime sur le nom de
	// la carte et sert aussi quand la carte n'a jamais pu être lue.
	Name string
	// Timeout borne la lecture de la carte et l'établissement de la connexion ;
	// il est obligatoire (> 0). Le délai global d'une tâche relève de l'appelant
	// (via le contexte de Send).
	Timeout time.Duration
	// HTTPClient remplace le client HTTP par défaut (tests, proxy) ; nil = client
	// à délais construits à partir de Timeout. Un client fourni sert tel quel.
	HTTPClient *http.Client
	// Logger reçoit les traces de niveau debug ; nil = slog.Default().
	Logger *slog.Logger
}

// Agent implémente port.RemoteAgent.
type Agent struct {
	cardURL  *url.URL
	name     string // nom d'affichage configuré ; vide : nom de la carte
	timeout  time.Duration
	client   *http.Client // flux de tâche : pas de délai global
	resolver *agentcard.Resolver
	log      *slog.Logger

	mu       sync.Mutex
	lastName string
	lastTags []string // tags de la dernière carte valide ; nil : jamais lue
}

var _ port.RemoteAgent = (*Agent)(nil)

// New valide les options. Elle n'effectue aucun appel réseau.
func New(opts Options) (*Agent, error) {
	u, err := url.Parse(opts.CardURL)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Hostname() == "" {
		return nil, errors.New("a2aclient : l'URL de la carte doit être http ou https avec un hôte")
	}
	if opts.Timeout <= 0 {
		return nil, errors.New("a2aclient : Timeout strictement positif obligatoire")
	}
	log := opts.Logger
	if log == nil {
		log = slog.Default()
	}
	var hc http.Client
	if opts.HTTPClient != nil {
		hc = *opts.HTTPClient
	} else {
		hc.Transport = &http.Transport{
			DialContext:           (&net.Dialer{Timeout: opts.Timeout}).DialContext,
			TLSHandshakeTimeout:   opts.Timeout,
			ResponseHeaderTimeout: opts.Timeout,
			MaxIdleConns:          2,
			IdleConnTimeout:       30 * time.Second,
		}
	}
	// Une redirection pourrait sortir de l'origine validée : on ne la suit pas.
	hc.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	return &Agent{
		cardURL:  u,
		name:     opts.Name,
		timeout:  opts.Timeout,
		client:   &hc,
		resolver: agentcard.NewResolver(&hc),
		log:      log,
	}, nil
}

// LastName renvoie le nom de la dernière carte valide lue ("" si aucune).
func (a *Agent) LastName() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.lastName
}

// LastTags renvoie une copie des tags de la dernière carte valide lue (nil si
// aucune).
func (a *Agent) LastTags() []string {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.lastTags == nil {
		return nil
	}
	return append([]string{}, a.lastTags...)
}

// ID est l'identité stable de l'agent : l'URL de carte configurée, sans
// identifiants ni requête.
func (a *Agent) ID() string {
	u := *a.cardURL
	u.User, u.RawQuery, u.Fragment = nil, "", ""
	return u.String()
}

// Name renvoie le nom configuré, sinon LastName (nettoyé), sinon l'hôte de l'URL de la carte.
func (a *Agent) Name() string {
	if a.name != "" {
		return a.name
	}
	if n := a.LastName(); n != "" {
		return n
	}
	return a.cardURL.Hostname()
}

// Card relit la carte à chaque appel.
func (a *Agent) Card(ctx context.Context) (port.AgentCard, error) {
	card, err := a.fetchCard(ctx)
	if err != nil {
		return port.AgentCard{}, err
	}
	// Handle porte la carte brute (déjà validée) pour que Send ne la relise pas.
	out := port.AgentCard{Name: card.Name, Description: card.Description, Handle: card}
	for i, s := range card.Skills {
		out.Skills = append(out.Skills, s.ID)
		if i == 0 {
			out.Label = s.Name
		}
	}
	out.Tags = cardTags(card)
	return out, nil
}

const (
	maxCardTags     = 32
	maxCardTagRunes = 40
)

// cardTags est l'union dédupliquée des tags des skills, bornée : une carte est
// une donnée non fiable. Au plus 32 tags de 1 à 40 runes, sans caractère de
// contrôle ; les autres sont écartés. Jamais nil.
func cardTags(card *a2a.AgentCard) []string {
	tags := []string{}
	seen := map[string]bool{}
	for _, s := range card.Skills {
		for _, tag := range s.Tags {
			n := utf8.RuneCountInString(tag)
			if n < 1 || n > maxCardTagRunes || seen[tag] || strings.ContainsFunc(tag, unicode.IsControl) {
				continue
			}
			if len(tags) == maxCardTags {
				return tags
			}
			seen[tag] = true
			tags = append(tags, tag)
		}
	}
	return tags
}

// cardLabel est le libellé d'activité : le nom du premier skill, sinon son
// identifiant, sinon vide.
func cardLabel(card *a2a.AgentCard) string {
	if len(card.Skills) == 0 {
		return ""
	}
	if n := card.Skills[0].Name; n != "" {
		return n
	}
	return card.Skills[0].ID
}

// maxCardNameRunes borne le nom d'affichage issu d'une carte distante.
const maxCardNameRunes = 40

// cleanCardName nettoie le nom d'une carte distante (non fiable) : les blancs
// (retours à la ligne compris) deviennent des espaces normalisés, les autres
// caractères de contrôle et de formatage (bidi, largeur nulle) sont retirés,
// le résultat est borné à maxCardNameRunes. Vide si rien ne reste.
func cleanCardName(raw string) string {
	var b strings.Builder
	for _, r := range raw {
		switch {
		case unicode.IsSpace(r):
			b.WriteByte(' ')
		case unicode.IsControl(r), unicode.Is(unicode.Cf, r):
		default:
			b.WriteRune(r)
		}
	}
	name := strings.Join(strings.Fields(b.String()), " ")
	if utf8.RuneCountInString(name) > maxCardNameRunes {
		name = strings.TrimSpace(string([]rune(name)[:maxCardNameRunes]))
	}
	return name
}

// fetchCard lit la carte et la valide ; seule l'interface JSON-RPC de même
// origine que CardURL est conservée dans la carte renvoyée.
func (a *Agent) fetchCard(ctx context.Context) (*a2a.AgentCard, error) {
	cctx, cancel := context.WithTimeout(ctx, a.timeout)
	defer cancel()
	card, err := a.resolver.Resolve(cctx, a.cardURL.String())
	if err != nil {
		a.log.Debug("a2aclient : lecture de la carte impossible", "err", err)
		return nil, classify(ctx, cctx, err, port.AgentUnreachable, "carte illisible")
	}
	var kept []*a2a.AgentInterface
	for _, i := range card.SupportedInterfaces {
		if i == nil || i.ProtocolBinding != a2a.TransportProtocolJSONRPC {
			continue
		}
		if !a.sameOrigin(i.URL) {
			a.log.Debug("a2aclient : interface hors origine rejetée")
			return nil, &port.AgentError{Kind: port.AgentProtocol, Reason: "interface de la carte hors origine"}
		}
		kept = append(kept, i)
	}
	if len(kept) == 0 {
		return nil, &port.AgentError{Kind: port.AgentProtocol, Reason: "aucune interface JSON-RPC annoncée"}
	}
	card.SupportedInterfaces = kept
	card.Name = cleanCardName(card.Name)
	if card.Name == "" {
		card.Name = a.cardURL.Hostname()
	}
	a.mu.Lock()
	a.lastName = card.Name
	a.lastTags = cardTags(card)
	a.mu.Unlock()
	return card, nil
}

func (a *Agent) sameOrigin(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil {
		return false
	}
	return strings.EqualFold(u.Scheme, a.cardURL.Scheme) &&
		strings.EqualFold(u.Hostname(), a.cardURL.Hostname()) &&
		portOf(u) == portOf(a.cardURL)
}

func portOf(u *url.URL) string {
	if p := u.Port(); p != "" {
		return p
	}
	if strings.EqualFold(u.Scheme, "https") {
		return "443"
	}
	return "80"
}

// classify range une erreur de transport dans une nature fermée, sans en
// exposer le texte (qui peut contenir une URL).
func classify(ctx, opCtx context.Context, err error, def port.AgentErrorKind, reason string) *port.AgentError {
	switch {
	case ctx.Err() != nil && errors.Is(ctx.Err(), context.Canceled):
		return &port.AgentError{Kind: port.AgentCanceled, Reason: "contexte annulé"}
	case errors.Is(err, context.DeadlineExceeded), opCtx.Err() != nil && errors.Is(opCtx.Err(), context.DeadlineExceeded):
		return &port.AgentError{Kind: port.AgentTimeout, Reason: "délai dépassé"}
	}
	var ne net.Error
	var ue *url.Error
	if errors.As(err, &ne) || errors.As(err, &ue) {
		return &port.AgentError{Kind: port.AgentUnreachable, Reason: "agent injoignable"}
	}
	return &port.AgentError{Kind: def, Reason: reason}
}

// Send implémente port.RemoteAgent.
func (a *Agent) Send(ctx context.Context, req port.AgentRequest) iter.Seq2[port.AgentUpdate, error] {
	return func(yield func(port.AgentUpdate, error) bool) {
		s := &stream{a: a, ctx: ctx, yield: yield}
		s.run(req)
	}
}

// stream porte l'état d'un envoi.
type stream struct {
	a      *Agent
	ctx    context.Context
	yield  func(port.AgentUpdate, error) bool
	client *sdk.Client
	taskID a2a.TaskID
	done   bool // un état terminal (a2a) ou un arrêt a été vu
	// name et label viennent de l'unique lecture de carte de l'envoi.
	name, label string
}

// fail émet UpdateFailed (et l'erreur) ; renvoie false : l'itération s'arrête.
func (s *stream) fail(err *port.AgentError) bool {
	s.yield(port.AgentUpdate{Kind: port.UpdateFailed, TaskID: string(s.taskID), Err: err}, err)
	return false
}

func (s *stream) emit(u port.AgentUpdate) bool {
	u.TaskID = string(s.taskID)
	return s.yield(u, nil)
}

func (s *stream) run(req port.AgentRequest) {
	card := readCard(req.Card)
	if card == nil {
		var err error
		if card, err = s.a.fetchCard(s.ctx); err != nil {
			var ae *port.AgentError
			errors.As(err, &ae)
			s.fail(ae)
			return
		}
	}
	s.name, s.label = card.Name, cardLabel(card)
	if s.a.name != "" {
		s.name = s.a.name
	}
	cctx, cancel := context.WithTimeout(s.ctx, s.a.timeout)
	client, err := sdk.NewFromCard(cctx, card, sdk.WithDefaultsDisabled(), sdk.WithJSONRPCTransport(s.a.client))
	cancel()
	if err != nil {
		s.a.log.Debug("a2aclient : création du client impossible", "err", err)
		s.fail(classify(s.ctx, cctx, err, port.AgentProtocol, "client A2A impossible"))
		return
	}
	s.client = client
	// Fin de l'envoi : annulation de la tâche distante si elle n'est pas
	// terminale, puis libération du client.
	defer func() {
		s.cancelRemote()
		if err := client.Destroy(); err != nil {
			s.a.log.Debug("a2aclient : Destroy", "err", err)
		}
	}()

	msg := a2a.NewMessage(a2a.MessageRoleUser, a2a.NewTextPart(req.Text))
	msg.ContextID = req.ContextID
	active := make([]any, 0, len(req.ActiveSurfaces))
	for _, id := range req.ActiveSurfaces {
		active = append(active, id)
	}
	msg.Metadata = map[string]any{ActiveSurfacesKey: active}
	for ev, err := range client.SendStreamingMessage(s.ctx, &a2a.SendMessageRequest{Message: msg}) {
		if err != nil {
			s.a.log.Debug("a2aclient : erreur de flux", "err", err)
			kind := port.AgentUnreachable
			if s.taskID != "" {
				kind = port.AgentFailed
			}
			s.fail(classify(s.ctx, s.ctx, err, kind, "flux interrompu"))
			return
		}
		if !s.handle(ev) {
			return
		}
	}
	if s.ctx.Err() != nil {
		s.fail(classify(s.ctx, s.ctx, s.ctx.Err(), port.AgentCanceled, "contexte annulé"))
		return
	}
	s.fail(&port.AgentError{Kind: port.AgentProtocol, Reason: "flux terminé sans état final"})
}

// readCard extrait la carte brute d'une carte lue par Card ; nil si la carte est
// absente ou ne vient pas de cet adaptateur (poignée absente ou d'un autre type).
func readCard(c *port.AgentCard) *a2a.AgentCard {
	if c == nil {
		return nil
	}
	raw, _ := c.Handle.(*a2a.AgentCard)
	return raw
}

// handle convertit un événement ; renvoie false quand l'itération doit s'arrêter.
func (s *stream) handle(ev a2a.Event) bool {
	switch e := ev.(type) {
	case *a2a.Task:
		if !s.noteTask(e.ID) {
			return false
		}
		return s.status(e.Status.State, e.Status.Message)
	case *a2a.TaskStatusUpdateEvent:
		if !s.noteTask(e.TaskID) {
			return false
		}
		return s.status(e.Status.State, e.Status.Message)
	case *a2a.TaskArtifactUpdateEvent:
		if !s.noteTask(e.TaskID) {
			return false
		}
		for _, p := range e.Artifact.Parts {
			if t := p.Text(); t != "" {
				if !s.emit(port.AgentUpdate{Kind: port.UpdateText, Text: t}) {
					return false
				}
			}
		}
		return true
	default:
		return s.fail(&port.AgentError{Kind: port.AgentProtocol, Reason: "message direct au lieu d'une tâche"})
	}
}

// noteTask retient l'identifiant de tâche d'un événement. Le premier
// identifiant vu émet UpdateSubmitted (quel que soit l'état de la tâche, qui
// peut arriver directement en `working`) ; un identifiant qui change ensuite
// est une erreur de protocole. Renvoie false quand l'itération doit s'arrêter.
func (s *stream) noteTask(id a2a.TaskID) bool {
	switch {
	case id == "" || id == s.taskID:
		return true
	case s.taskID != "":
		return s.fail(&port.AgentError{Kind: port.AgentProtocol, Reason: "identifiant de tâche modifié en cours de flux"})
	}
	s.taskID = id
	return s.emit(port.AgentUpdate{Kind: port.UpdateSubmitted, Name: s.name, Label: s.label})
}

func (s *stream) status(st a2a.TaskState, msg *a2a.Message) bool {
	switch st {
	case a2a.TaskStateSubmitted:
		return true // UpdateSubmitted a déjà été émis par noteTask
	case a2a.TaskStateWorking:
		if msg == nil {
			return true
		}
		for _, p := range msg.Parts {
			d := p.Data()
			if d == nil {
				continue // part texte ou autre : sans effet
			}
			m, ok := d.(map[string]any)
			if !ok {
				return s.fail(&port.AgentError{Kind: port.AgentProtocol, Reason: "part non-map"})
			}
			if !s.emit(port.AgentUpdate{Kind: port.UpdateA2UI, A2UI: m}) {
				return false
			}
		}
		return true
	case a2a.TaskStateCompleted:
		s.done = true
		s.emit(port.AgentUpdate{Kind: port.UpdateCompleted})
		return false
	case a2a.TaskStateFailed:
		s.done = true
		return s.fail(&port.AgentError{Kind: port.AgentFailed, Reason: "tâche échouée"})
	case a2a.TaskStateRejected:
		s.done = true
		return s.fail(&port.AgentError{Kind: port.AgentRejected, Reason: "demande refusée"})
	case a2a.TaskStateCanceled:
		s.done = true
		return s.fail(&port.AgentError{Kind: port.AgentCanceled, Reason: "tâche annulée"})
	case a2a.TaskStateInputRequired:
		return s.fail(&port.AgentError{Kind: port.AgentFailed, Reason: "entrée supplémentaire demandée"})
	case a2a.TaskStateAuthRequired:
		return s.fail(&port.AgentError{Kind: port.AgentFailed, Reason: "authentification demandée"})
	}
	return true
}

// cancelRemote émet CancelTask (contexte neuf, 1 s) si la tâche est connue et
// non terminale.
func (s *stream) cancelRemote() {
	if s.taskID == "" || s.done {
		return
	}
	ctx, cancel := context.WithTimeout(context.WithoutCancel(s.ctx), cancelTimeout)
	defer cancel()
	if _, err := s.client.CancelTask(ctx, &a2a.CancelTaskRequest{ID: s.taskID}); err != nil {
		s.a.log.Debug("a2aclient : CancelTask", "err", err)
	}
}
