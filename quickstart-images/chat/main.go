// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

// Command quickstart-chat serves one chat page for the quickstart agent and
// forwards the page's requests to the agent's own HTTP API, so the reader
// chats with the agent, and the agent with its model. It keeps nothing: each
// conversation lives in the agent, under the thread name the page chooses.
//
// It is configured only from its environment. AGENT_URL is where the agent
// answers, http://agent:8000 when unset. CHAT_SUBTITLE is the sentence shown
// under the page's header, naming what answers; a neutral sentence when unset.
// It listens on port 8090.
//
//	GET  /                          the chat page
//	GET  /page/{file}               the page's script, stylesheet and images
//	POST /threads/{thread}/turns    one turn, forwarded to the agent
//	GET  /threads/{thread}          the conversation so far, from the agent
//	GET  /healthz                   whether the agent answers
//
// Everything the page loads is served from this binary; the page loads nothing
// from anywhere else.
package main

import (
	"bytes"
	"context"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"io"
	"io/fs"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"regexp"
	"strings"
	"syscall"
	"time"
)

const (
	listenAddr      = ":8090"
	defaultAgentURL = "http://agent:8000"
	defaultSubtitle = "Answers come from the model behind the quickstart agent."
	// The largest turn body this server forwards, in bytes, counted as sent.
	// The agent reads this much of a request body and no more, so a body within
	// it reaches the agent whole. The agent is a separate Python image, so the
	// number is a deliberate copy of its limit: change both together.
	maxTurnBody = 16384
	// Bounds what is read back from the agent: a long conversation's history.
	maxAgentReply = 4 << 20
	// A small model on a laptop's processor can take minutes over one answer,
	// the first after a start most of all.
	agentTimeout = 5 * time.Minute
)

// The thread names this server puts into the agent's request path: letters,
// digits, dots, underscores and hyphens only, so a name can never add a path
// segment, a query or an escape to the request it builds. The page is handed
// this same pattern and checks a stored name against it.
var threadName = regexp.MustCompile(`^[A-Za-z0-9._-]{1,64}$`)

//go:embed page
var pageFiles embed.FS

// The page's own policy: everything it loads, and every request it sends,
// comes from this server.
const contentSecurityPolicy = "default-src 'self'; img-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'"

type service struct {
	agent    *url.URL
	client   *http.Client
	page     *template.Template
	subtitle string
}

func main() {
	log.SetFlags(log.LstdFlags | log.LUTC)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()

	agentURL := envOr("AGENT_URL", defaultAgentURL)
	agent, err := url.Parse(agentURL)
	if err != nil || (agent.Scheme != "http" && agent.Scheme != "https") || agent.Host == "" {
		log.Fatalf("AGENT_URL is %q: write the agent's address as http://<host>:<port>", agentURL)
	}
	s := &service{
		agent:    agent,
		client:   &http.Client{Timeout: agentTimeout},
		page:     template.Must(template.ParseFS(pageFiles, "page/index.html")),
		subtitle: envOr("CHAT_SUBTITLE", defaultSubtitle),
	}
	static, err := fs.Sub(pageFiles, "page")
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("quickstart-chat: agent %s", agent.Redacted())

	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.index)
	mux.Handle("GET /page/", http.StripPrefix("/page/", http.FileServerFS(static)))
	mux.HandleFunc("POST /threads/{thread}/turns", s.turn)
	mux.HandleFunc("GET /threads/{thread}", s.history)
	mux.HandleFunc("GET /healthz", s.health)
	srv := &http.Server{Addr: listenAddr, Handler: secured(mux), ReadHeaderTimeout: 10 * time.Second}

	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdown)
	}()
	log.Printf("listening on %s", listenAddr)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func envOr(name, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(name)); v != "" {
		return v
	}
	return fallback
}

// secured sets the headers every answer carries.
func secured(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Content-Security-Policy", contentSecurityPolicy)
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}

func (s *service) index(w http.ResponseWriter, r *http.Request) {
	var page bytes.Buffer
	data := map[string]string{"Subtitle": s.subtitle, "ThreadPattern": threadName.String()}
	if err := s.page.Execute(&page, data); err != nil {
		http.Error(w, "the page could not be written", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = page.WriteTo(w)
}

func (s *service) turn(w http.ResponseWriter, r *http.Request) {
	thread, ok := s.thread(w, r)
	if !ok {
		return
	}
	tooLong := fmt.Sprintf("the message is too long: a turn is forwarded to the agent as at most %d bytes of JSON", maxTurnBody)
	var body struct {
		Message string `json:"message"`
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, maxTurnBody+1))
	if err == nil && len(raw) > maxTurnBody {
		writeError(w, http.StatusRequestEntityTooLarge, tooLong)
		return
	}
	if err != nil || json.Unmarshal(raw, &body) != nil || strings.TrimSpace(body.Message) == "" {
		writeError(w, http.StatusBadRequest, `send a JSON body such as {"message": "Hello"}`)
		return
	}
	// Only the message is forwarded, re-encoded, whatever else the body held.
	// It is encoded without escaping <, > and &, which would otherwise grow by
	// six bytes each, and the bound is checked on the bytes actually forwarded.
	var forward bytes.Buffer
	enc := json.NewEncoder(&forward)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(map[string]string{"message": body.Message}); err != nil {
		writeError(w, http.StatusBadRequest, `send a JSON body such as {"message": "Hello"}`)
		return
	}
	if forward.Len() > maxTurnBody {
		writeError(w, http.StatusRequestEntityTooLarge, tooLong)
		return
	}
	s.forward(w, r, http.MethodPost, "/threads/"+thread+"/turns", forward.Bytes())
}

func (s *service) history(w http.ResponseWriter, r *http.Request) {
	if thread, ok := s.thread(w, r); ok {
		s.forward(w, r, http.MethodGet, "/threads/"+thread, nil)
	}
}

func (s *service) health(w http.ResponseWriter, r *http.Request) {
	s.forward(w, r, http.MethodGet, "/healthz", nil)
}

func (s *service) thread(w http.ResponseWriter, r *http.Request) (string, bool) {
	thread := r.PathValue("thread")
	if !threadName.MatchString(thread) {
		writeError(w, http.StatusBadRequest, "a thread name is 1 to 64 letters, digits, dots, underscores or hyphens")
		return "", false
	}
	return thread, true
}

// forward sends one request to the agent and answers with the agent's own
// status and JSON body.
func (s *service) forward(w http.ResponseWriter, r *http.Request, method, path string, body []byte) {
	req, err := http.NewRequestWithContext(r.Context(), method, s.agent.JoinPath(path).String(), bytes.NewReader(body))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := s.client.Do(req)
	if err != nil {
		log.Printf("%s %s: the agent does not answer: %v", method, path, err)
		writeError(w, http.StatusBadGateway, "the agent at "+s.agent.Redacted()+" does not answer: "+err.Error())
		return
	}
	defer resp.Body.Close()
	reply, err := io.ReadAll(io.LimitReader(resp.Body, maxAgentReply+1))
	if err != nil || len(reply) > maxAgentReply {
		writeError(w, http.StatusBadGateway, "the agent's answer could not be read in full")
		return
	}
	log.Printf("%s %s: agent answered %d", method, path, resp.StatusCode)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(reply)
}

// writeError is this program's own: each quickstart image builds from its own
// directory and module, so the same helper in the web image cannot be shared.
func writeError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}
