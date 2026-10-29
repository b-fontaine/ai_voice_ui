// Outil TTS jetable du spike SP-02 : liste les modèles TTS (gratuit) et génère des fichiers Ogg/Opus.
// La clé est lue dans OPENAI_API_KEY et n'est jamais affichée.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

var key = os.Getenv("OPENAI_API_KEY")

func redact(s string) string {
	if key != "" {
		s = strings.ReplaceAll(s, key, "[REDACTED]")
	}
	return s
}

func do(req *http.Request) ([]byte, error) {
	req.Header.Set("Authorization", "Bearer "+key)
	c := &http.Client{Timeout: 60 * time.Second}
	resp, err := c.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%s", redact(err.Error()))
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d : %s", resp.StatusCode, redact(string(b)))
	}
	return b, nil
}

func listModels(filter string) []string {
	req, _ := http.NewRequest("GET", "https://api.openai.com/v1/models", nil)
	b, err := do(req)
	if err != nil {
		log.Fatal(err)
	}
	var r struct{ Data []struct{ ID string } }
	if err := json.Unmarshal(b, &r); err != nil {
		log.Fatal(err)
	}
	var ids []string
	for _, m := range r.Data {
		if filter == "" || strings.Contains(m.ID, filter) {
			ids = append(ids, m.ID)
		}
	}
	sort.Strings(ids)
	return ids
}

var phrases = map[string]string{
	"q1":      "Bonjour, peux-tu me dire où en est la release trois point quatre ?",
	"q2":      "Donne-moi le taux de sessions sans crash sur sept jours.",
	"bargein": "Stop, attends, arrête-toi un instant.",
	"long":    "Raconte-moi en détail, étape par étape, comment se prépare une release mobile.",
}

func main() {
	list := flag.String("list", "", "liste les modèles dont l'id contient cette chaîne (gratuit), puis sort")
	model := flag.String("model", "", "modèle TTS (issu de -list tts)")
	voice := flag.String("voice", "alloy", "voix")
	out := flag.String("out", "", "répertoire de sortie")
	only := flag.String("only", "", "ne générer que ce fichier (q1|q2|bargein|long)")
	flag.Parse()
	if key == "" {
		log.Fatal("OPENAI_API_KEY absente")
	}
	if *list != "" {
		for _, id := range listModels(*list) {
			fmt.Println(id)
		}
		return
	}
	if *model == "" || *out == "" {
		log.Fatal("-model et -out requis")
	}
	var totalChars int
	for name, text := range phrases {
		if *only != "" && *only != name {
			continue
		}
		body := map[string]any{"model": *model, "voice": *voice, "input": text, "response_format": "opus"}
		if strings.Contains(*model, "gpt-") { // les modèles gpt-*-tts acceptent `instructions`
			body["instructions"] = "Parle en français, naturellement, à vitesse normale."
		}
		b, _ := json.Marshal(body)
		req, _ := http.NewRequest("POST", "https://api.openai.com/v1/audio/speech", bytes.NewReader(b))
		req.Header.Set("Content-Type", "application/json")
		audio, err := do(req)
		if err != nil {
			log.Fatalf("%s : %v", name, err)
		}
		p := filepath.Join(*out, name+".ogg")
		if err := os.WriteFile(p, audio, 0o600); err != nil {
			log.Fatal(err)
		}
		totalChars += len(text)
		fmt.Printf("%s : %d octets, entête %q\n", p, len(audio), string(audio[:4]))
	}
	fmt.Printf("caractères synthétisés : %d\n", totalChars)
}
