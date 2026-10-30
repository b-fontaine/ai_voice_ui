package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// act3Params regroupe ce dont le déroulé réel du scénario act3 a besoin.
type act3Params struct {
	j           *journal
	filtered    *collector
	pl          *player
	pk2         []opusPacket
	baseURL     string
	actTimeout  time.Duration // attente maximale de la fin de chaque acte
	settle      time.Duration // silence de la voix exigé avant la 2e question et avant le clic
	clickWindow time.Duration // observation après le clic
}

const clickBody = `{"action":"block_release","surface":"actions"}`

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
	quiet := func() bool {
		return quietAI(p.filtered.snapshot(), time.Now().UnixMilli(), p.settle.Milliseconds())
	}

	if ok, why := waitUntil(ctx, p.actTimeout, p.filtered.closed, func() bool { return act1Done(p.filtered.snapshot()) }); !ok {
		return abort("acte 1 non terminé", why)
	}
	p.j.write(map[string]any{"type": "act3.act1_done"})
	if ok, why := waitUntil(ctx, p.actTimeout, p.filtered.closed, quiet); !ok {
		return abort("voix encore active après l'acte 1", why)
	}

	o.Play2UnixMs = time.Now().UnixMilli()
	p.j.write(map[string]any{"type": "local.file2", "packets": len(p.pk2)})
	p.pl.play(p.pk2)
	since := o.Play2UnixMs
	if ok, why := waitUntil(ctx, p.actTimeout, p.filtered.closed, func() bool { return act2Done(p.filtered.snapshot(), since) }); !ok {
		return abort("acte 2 non terminé", why)
	}
	p.j.write(map[string]any{"type": "act3.act2_done"})
	if ok, why := waitUntil(ctx, p.actTimeout, p.filtered.closed, quiet); !ok {
		return abort("voix encore active après l'acte 2", why)
	}

	// Le clic : POST HTTP brut, sans Origin, comme l'app desktop.
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/canvas/actions", strings.NewReader(clickBody))
	if err != nil {
		return abort("clic", err.Error())
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 10 * time.Second}
	o.ClickUnixMs = time.Now().UnixMilli()
	resp, err := client.Do(req)
	o.RespUnixMs = time.Now().UnixMilli()
	if err != nil {
		o.ClickErr = errText(err)
		p.j.write(map[string]any{"type": "act3.click", "error": o.ClickErr})
		return o
	}
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
	resp.Body.Close()
	o.ClickStatus, o.ClickBody = resp.StatusCode, string(body)
	p.j.write(map[string]any{"type": "act3.click", "status": resp.StatusCode, "body_bytes": len(body)})
	if resp.StatusCode != http.StatusAccepted {
		return o
	}

	select {
	case <-time.After(p.clickWindow):
	case <-p.filtered.closed:
	case <-ctx.Done():
	}
	return o
}
