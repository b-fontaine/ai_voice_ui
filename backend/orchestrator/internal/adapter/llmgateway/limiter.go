package llmgateway

import (
	"math"
	"sync"
	"time"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// limiter est un seau à jetons : burst jetons au plus, un jeton rendu par fenêtre.
type limiter struct {
	clock  port.Clock
	burst  float64
	window time.Duration

	mu     sync.Mutex
	tokens float64
	last   time.Time
}

func newLimiter(clock port.Clock, burst int, window time.Duration) *limiter {
	return &limiter{clock: clock, burst: float64(burst), window: window, tokens: float64(burst), last: clock.Now()}
}

// allow consomme un jeton ; sinon renvoie le délai d'attente en secondes entières (>= 1).
func (l *limiter) allow() (bool, int) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.clock.Now()
	if elapsed := now.Sub(l.last); elapsed > 0 {
		l.tokens = math.Min(l.burst, l.tokens+float64(elapsed)/float64(l.window))
	}
	l.last = now
	if l.tokens >= 1 {
		l.tokens--
		return true, 0
	}
	wait := time.Duration((1 - l.tokens) * float64(l.window))
	secs := int(math.Ceil(wait.Seconds()))
	if secs < 1 {
		secs = 1
	}
	return false, secs
}
