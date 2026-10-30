//go:build acceptance

package acceptance

import "github.com/a2aproject/a2a-go/v2/a2a"

// stateOf renvoie l'état de tâche porté par un événement, ou "" s'il n'en porte pas.
func stateOf(ev a2a.Event) a2a.TaskState {
	switch e := ev.(type) {
	case *a2a.Task:
		return e.Status.State
	case *a2a.TaskStatusUpdateEvent:
		return e.Status.State
	}
	return ""
}

func statusMessage(ev a2a.Event) *a2a.Message {
	switch e := ev.(type) {
	case *a2a.Task:
		return e.Status.Message
	case *a2a.TaskStatusUpdateEvent:
		return e.Status.Message
	}
	return nil
}
