package voice

import (
	"context"

	"github.com/b-fontaine/ai_voice_ui/backend/orchestrator/internal/port"
)

// sidebandReply adapte le sideband d'une session au port VoiceReply remis aux
// délégations : un commentaire de délégation garde son identifiant ; une
// annonce part hors de toute délégation (`delegation_id` nul).
//
// Annonce minimale : un seul envoi, sans repli. La politique de repli (dernière
// délégation, consigne de l'orchestrateur, observation du transcript) viendra
// s'appuyer sur AppendGeneralCommentary.
type sidebandReply struct{ sb port.Sideband }

var _ port.VoiceReply = sidebandReply{}

func (r sidebandReply) AppendCommentary(ctx context.Context, delegationID, text string) error {
	return r.sb.AppendCommentary(ctx, delegationID, text)
}

func (r sidebandReply) Announce(ctx context.Context, text string) error {
	return r.sb.AppendGeneralCommentary(ctx, text)
}
