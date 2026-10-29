// Package openailive est l'adaptateur sortant vers l'API OpenAI Live
// (session WebRTC créée côté backend, canal latéral « sideband » en WebSocket).
// Il implémente port.LiveProvider ; la clé API n'en sort jamais.
package openailive

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/openai/openai-go/v3"
	"github.com/openai/openai-go/v3/live"
	"github.com/openai/openai-go/v3/option"
	"github.com/openai/openai-go/v3/packages/param"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// OutputSampleRate est la fréquence d'échantillonnage (Hz) de la sortie audio
// de gpt-live : PCM16 mono 24 kHz [rt-gpt-live-output-level].
const OutputSampleRate = 24000

const (
	delegationClient    = "client"
	delegationResponses = "responses"
	delegationDecisions = "decisions"
)

// Options configure l'adaptateur. Aucune valeur par défaut n'est codée en dur,
// sauf BaseURL vide (défaut du SDK).
type Options struct {
	APIKey         string
	BaseURL        string // vide : URL par défaut du SDK ; sert aux tests
	Model          string
	Voice          string
	DelegationType string // seul « client » est pris en charge
	Instructions   string

	// AppendAckTimeout borne l'attente de l'acquittement d'un commentaire
	// vocal (VOICE_APPEND_ACK_TIMEOUT) ; obligatoire, strictement positif.
	AppendAckTimeout time.Duration
	// Logger reçoit les journaux de l'adaptateur ; nil : slog.Default().
	Logger *slog.Logger
}

// String décrit les options sans jamais exposer la clé.
func (o Options) String() string {
	return fmt.Sprintf("Options{Model:%q Voice:%q DelegationType:%q BaseURL:%q APIKey:[masquée]}",
		o.Model, o.Voice, o.DelegationType, o.BaseURL)
}

// GoString garantit que %#v ne révèle pas la clé.
func (o Options) GoString() string { return o.String() }

// Provider est le port.LiveProvider adossé à l'API OpenAI Live.
type Provider struct {
	client       openai.Client
	secret       string
	model        string
	voice        string
	instructions string
	delegation   live.MediaSessionConfigDelegationUnionParam
	ackTimeout   time.Duration
	log          *slog.Logger
}

var _ port.LiveProvider = (*Provider)(nil)

// String ne révèle aucun champ sensible.
func (p *Provider) String() string {
	return fmt.Sprintf("openailive.Provider{Model:%q Voice:%q APIKey:[masquée]}", p.model, p.voice)
}

// GoString garantit que %#v ne révèle pas la clé.
func (p *Provider) GoString() string { return p.String() }

// delegationParam construit le paramètre de délégation de la session. Les
// délégations « responses » et « decisions » ne sont pas prises en charge au MVP.
func delegationParam(kind string) (live.MediaSessionConfigDelegationUnionParam, error) {
	switch kind {
	case delegationClient:
		d := live.NewClientDelegationParam()
		return live.MediaSessionConfigDelegationUnionParam{OfClient: &d}, nil
	case delegationResponses, delegationDecisions:
		return live.MediaSessionConfigDelegationUnionParam{},
			fmt.Errorf("délégation %q non prise en charge au MVP, pdr-0050", kind)
	default:
		return live.MediaSessionConfigDelegationUnionParam{},
			fmt.Errorf("type de délégation %q inconnu (seul %q est pris en charge, pdr-0050)", kind, delegationClient)
	}
}

// New construit l'adaptateur ; il est le seul validateur du type de délégation.
func New(opts Options) (*Provider, error) {
	delegation, err := delegationParam(opts.DelegationType)
	if err != nil {
		return nil, err
	}
	if opts.APIKey == "" {
		return nil, errors.New("clé API du fournisseur voix manquante")
	}
	if opts.Model == "" || opts.Voice == "" {
		return nil, errors.New("modèle et voix du fournisseur voix obligatoires")
	}
	if opts.AppendAckTimeout <= 0 {
		return nil, errors.New("délai d'acquittement des commentaires vocaux (AppendAckTimeout) obligatoire et > 0")
	}
	logger := opts.Logger
	if logger == nil {
		logger = slog.Default()
	}
	reqOpts := []option.RequestOption{option.WithAPIKey(opts.APIKey)}
	if opts.BaseURL != "" {
		reqOpts = append(reqOpts, option.WithBaseURL(opts.BaseURL))
	}
	return &Provider{
		client:       openai.NewClient(reqOpts...),
		secret:       opts.APIKey,
		model:        opts.Model,
		voice:        opts.Voice,
		instructions: opts.Instructions,
		delegation:   delegation,
		ackTimeout:   opts.AppendAckTimeout,
		log:          logger,
	}, nil
}

// CreateSession crée la session WebRTC à partir de l'offre SDP du client.
func (p *Provider) CreateSession(ctx context.Context, offerSDP string) (port.LiveSession, error) {
	cfg := live.MediaSessionConfigParam{Model: live.MediaSessionConfigModel(p.model)}
	if p.instructions != "" {
		cfg.Instructions = param.NewOpt(p.instructions)
	}
	cfg.Audio.Output.Voice.OfString = param.NewOpt(p.voice)
	cfg.Delegation = p.delegation

	res, err := p.client.Live.New(ctx, live.LiveNewParams{
		Session:   cfg,
		Transport: live.LiveNewParamsTransport{Sdp: offerSDP},
	})
	if err != nil {
		return port.LiveSession{}, p.wrap("création de la session voix", err)
	}
	return port.LiveSession{ID: res.Session.ID, AnswerSDP: res.Transport.Sdp}, nil
}

// Sideband ouvre le canal latéral de la session. ctx borne seulement
// l'ouverture ; la vie du canal est portée par Sideband.Close.
func (p *Provider) Sideband(ctx context.Context, sessionID string) (port.Sideband, error) {
	conn, err := p.client.Live.Sideband.Connect(ctx, sessionID, live.SidebandConnectionOptions{})
	if err != nil {
		return nil, p.wrap("ouverture du sideband", err)
	}
	return newSideband(conn, p), nil
}

// Hangup termine la session chez le fournisseur ; l'erreur ne contient jamais
// la clé API.
func (p *Provider) Hangup(ctx context.Context, sessionID string) error {
	if err := p.client.Live.Sessions.Hangup(ctx, sessionID); err != nil {
		return p.wrap("raccrochage de la session voix", err)
	}
	return nil
}

// redactedError porte un message sans la clé ; seules les erreurs de contexte
// restent détectables par errors.Is.
type redactedError struct {
	msg   string
	cause error
}

func (e *redactedError) Error() string { return e.msg }
func (e *redactedError) Unwrap() error { return e.cause }

func (p *Provider) wrap(what string, err error) error {
	msg := strings.ReplaceAll(err.Error(), p.secret, "[masquée]")
	var cause error
	switch {
	case errors.Is(err, context.Canceled):
		cause = context.Canceled
	case errors.Is(err, context.DeadlineExceeded):
		cause = context.DeadlineExceeded
	}
	return &redactedError{msg: what + " : " + msg, cause: cause}
}
