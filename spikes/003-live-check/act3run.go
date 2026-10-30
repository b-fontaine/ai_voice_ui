package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// act3Params regroupe ce dont le déroulé réel du scénario act3 a besoin.
type act3Params struct {
	j              *journal
	filtered       *collector
	pl             *player
	pk2            []opusPacket
	baseURL        string
	actTimeout     time.Duration // attente maximale de la fin de chaque acte
	settle         time.Duration // silence de la voix exigé après son dernier commentaire
	commentaryWait time.Duration // attente maximale d'un commentaire vocal après la fin des agents
	clickWindow    time.Duration // observation après le clic
}

const (
	clickBody = `{"action":"block_release","surface":"actions"}`
	// Discipline de l'app (canvasActionRetries = 6, canvasActionRetryInterval = 1 s).
	clickRetries       = 6
	clickRetryInterval = time.Second
	clickMaxAttempts   = clickRetries + 1
)

// clickResult est la réponse d'un envoi du clic ; Err est non vide en cas d'erreur réseau.
type clickResult struct {
	Status int
	Body   string
	Err    string
	At     int64 // réception, en ms Unix
}

// code résume la réponse pour le rapport : « 202 », « 409 busy » ou « erreur réseau ».
func (r clickResult) code() string {
	if r.Err != "" {
		return "erreur réseau"
	}
	var e struct {
		Error string `json:"error"`
	}
	if json.Unmarshal([]byte(r.Body), &e) == nil && e.Error != "" {
		return fmt.Sprintf("%d %s", r.Status, e.Error)
	}
	return fmt.Sprint(r.Status)
}

// retryable : 409 busy ou no_session, comme dans l'app.
func (r clickResult) retryable() bool {
	return r.Err == "" && r.Status == http.StatusConflict &&
		(strings.Contains(r.Body, `"busy"`) || strings.Contains(r.Body, `"no_session"`))
}

// sendClick envoie le clic puis le renvoie, jusqu'à retries fois, tant que la réponse est 409
// busy ou no_session ; interval sépare deux envois. Il renvoie toutes les réponses obtenues.
func sendClick(ctx context.Context, do func() clickResult, retries int, interval time.Duration) []clickResult {
	var out []clickResult
	for i := 0; ; i++ {
		r := do()
		out = append(out, r)
		if !r.retryable() || i >= retries {
			return out
		}
		select {
		case <-time.After(interval):
		case <-ctx.Done():
			return out
		}
	}
}

// waitUntil interroge cond toutes les 200 ms jusqu'à l'échéance ; false si délai, serveur fermé ou annulation.
func waitUntil(ctx context.Context, timeout time.Duration, closed <-chan struct{}, cond func() bool) (bool, string) {
	deadline := time.NewTimer(timeout)
	defer deadline.Stop()
	tick := time.NewTicker(200 * time.Millisecond)
	defer tick.Stop()
	for {
		if cond() {
			return true, ""
		}
		select {
		case <-tick.C:
		case <-deadline.C:
			return false, fmt.Sprintf("délai de %s dépassé", timeout)
		case <-closed:
			return false, "session fermée par le serveur"
		case <-ctx.Done():
			return false, "interrompu (plafond de durée ou Ctrl-C)"
		}
	}
}

// runAct3 joue le déroulé réel : acte 1 (déjà lancé par l'appelant avec file1), 2e question,
// attente de l'acte 2, clic, observation. Il ne ferme pas la session (l'appelant le fait en defer).
func runAct3(ctx context.Context, p act3Params) act3Observations {
	var o act3Observations
	abort := func(acte, why string) act3Observations {
		o.Aborted = acte + " : " + why
		p.j.write(map[string]any{"type": "act3.abort", "reason": o.Aborted})
		return o
	}
	settled := func() bool {
		return delegationSettled(p.filtered.snapshot(), time.Now().UnixMilli(),
			p.settle.Milliseconds(), p.commentaryWait.Milliseconds())
	}

	if ok, why := waitUntil(ctx, p.actTimeout, p.filtered.closed, func() bool { return act1Done(p.filtered.snapshot()) }); !ok {
		return abort("acte 1 non terminé", why)
	}
	p.j.write(map[string]any{"type": "act3.act1_done"})
	if ok, why := waitUntil(ctx, p.actTimeout, p.filtered.closed, settled); !ok {
		return abort("délégation de l'acte 1 non terminée (voix)", why)
	}

	o.Play2UnixMs = time.Now().UnixMilli()
	p.j.write(map[string]any{"type": "local.file2", "packets": len(p.pk2)})
	p.pl.play(p.pk2)
	since := o.Play2UnixMs
	if ok, why := waitUntil(ctx, p.actTimeout, p.filtered.closed, func() bool { return act2Done(p.filtered.snapshot(), since) }); !ok {
		return abort("acte 2 non terminé", why)
	}
	p.j.write(map[string]any{"type": "act3.act2_done"})
	if ok, why := waitUntil(ctx, p.actTimeout, p.filtered.closed, settled); !ok {
		return abort("délégation de l'acte 2 non terminée (voix)", why)
	}

	// Le clic : POST HTTP brut, sans Origin, comme l'app desktop ; mêmes réessais que l'app.
	client := &http.Client{Timeout: 10 * time.Second}
	o.ClickUnixMs = time.Now().UnixMilli() // délais mesurés depuis le premier envoi
	results := sendClick(ctx, func() clickResult {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/canvas/actions", strings.NewReader(clickBody))
		if err != nil {
			return clickResult{Err: err.Error(), At: time.Now().UnixMilli()}
		}
		req.Header.Set("Content-Type", "application/json")
		resp, err := client.Do(req)
		at := time.Now().UnixMilli()
		if err != nil {
			return clickResult{Err: errText(err), At: at}
		}
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		resp.Body.Close()
		return clickResult{Status: resp.StatusCode, Body: string(body), At: at}
	}, clickRetries, clickRetryInterval)
	for i, r := range results {
		p.j.write(map[string]any{"type": "act3.click", "attempt": i + 1, "status": r.Status, "code": r.code(),
			"error": r.Err, "body_bytes": len(r.Body)})
		o.ClickCodes = append(o.ClickCodes, r.code())
	}
	last := results[len(results)-1]
	o.ClickAttempts, o.RespUnixMs = len(results), last.At
	o.ClickStatus, o.ClickBody, o.ClickErr = last.Status, last.Body, last.Err
	if last.Err != "" || last.Status != http.StatusAccepted {
		return o
	}

	select {
	case <-time.After(p.clickWindow):
	case <-p.filtered.closed:
	case <-ctx.Done():
	}
	return o
}
