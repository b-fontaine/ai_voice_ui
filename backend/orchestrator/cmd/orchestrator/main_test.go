package main

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net"
	"net/http"
	"sync/atomic"
	"testing"
	"time"
)

func freeAddr(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	return ln.Addr().String()
}

func newServer(addr string) *http.Server {
	return &http.Server{Addr: addr, Handler: http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })}
}

func reachable(addr string) bool {
	c, err := net.DialTimeout("tcp", addr, 200*time.Millisecond)
	if err != nil {
		return false
	}
	_ = c.Close()
	return true
}

func waitUp(t *testing.T, addrs ...string) {
	t.Helper()
	for _, a := range addrs {
		deadline := time.Now().Add(3 * time.Second)
		for !reachable(a) {
			if time.Now().After(deadline) {
				t.Fatalf("%s n'écoute pas", a)
			}
			time.Sleep(20 * time.Millisecond)
		}
	}
}

var quiet = slog.New(slog.NewTextHandler(io.Discard, nil))

// Arrêt demandé (signal) : les deux serveurs s'arrêtent et l'application est fermée une fois.
func TestServe_ShutsDownBothServersOnSignal(t *testing.T) {
	a, b := freeAddr(t), freeAddr(t)
	var closed atomic.Int32
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() {
		done <- serve(ctx, quiet, []*http.Server{newServer(a), newServer(b)}, func(context.Context) error { closed.Add(1); return nil }, 3*time.Second)
	}()
	waitUp(t, a, b)
	cancel()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("arrêt propre attendu : %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("serve ne rend pas la main")
	}
	if reachable(a) || reachable(b) {
		t.Error("un serveur écoute encore")
	}
	if closed.Load() != 1 {
		t.Errorf("fermeture de l'application appelée %d fois, attendu 1", closed.Load())
	}
}

// La chute de l'un (adresse déjà prise) arrête l'autre, ferme l'application et rend l'erreur.
func TestServe_FailureOfOneStopsTheOther(t *testing.T) {
	a := freeAddr(t)
	busy, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer busy.Close()
	var closed atomic.Int32
	done := make(chan error, 1)
	go func() {
		done <- serve(context.Background(), quiet, []*http.Server{newServer(a), newServer(busy.Addr().String())},
			func(context.Context) error { closed.Add(1); return nil }, 3*time.Second)
	}()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("l'erreur d'écoute doit être rendue")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("la chute d'un serveur n'arrête pas l'autre")
	}
	if reachable(a) {
		t.Error("le premier serveur écoute encore après la chute du second")
	}
	if closed.Load() != 1 {
		t.Errorf("fermeture de l'application appelée %d fois, attendu 1", closed.Load())
	}
}

// Les erreurs d'arrêt et de fermeture sont réunies (errors.Join).
func TestServe_JoinsShutdownErrors(t *testing.T) {
	a := freeAddr(t)
	boom := errors.New("fermeture en échec")
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() {
		done <- serve(ctx, quiet, []*http.Server{newServer(a)}, func(context.Context) error { return boom }, time.Second)
	}()
	waitUp(t, a)
	cancel()
	if err := <-done; !errors.Is(err, boom) {
		t.Fatalf("err = %v, attendu l'erreur de fermeture", err)
	}
}
