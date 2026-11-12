// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cognitio S.r.l.

// Command quickstart-web is a small HTTP service that keeps short notes in
// PostgreSQL and, when a Redis cache is wired to it, answers a note it has
// already read from the cache. Every answer about a note names where it came
// from, so the cache is visible from outside.
//
// It is configured only from its environment. PostgreSQL is reached through
// the variables the PostgreSQL client libraries read by convention, PGHOST,
// PGPORT, PGUSER, PGPASSWORD and PGDATABASE. The cache is reached at
// REDIS_HOST and REDIS_PORT; with REDIS_HOST unset the service runs without
// one. It listens on port 8080.
//
//	POST /notes        the request body is stored as a new note
//	GET  /notes/{id}   one note, from the cache when it holds it
//	GET  /notes        the most recent notes, from PostgreSQL
//	GET  /             what the service is connected to; to a browser, the page
//	GET  /page/{file}  the page's script, stylesheets and images
//	GET  /healthz      whether PostgreSQL answers
//
// The page is served only to a request whose Accept header prefers HTML, as a
// browser's does; every other request to / gets the JSON. Everything the page
// loads is served from this binary; the page loads nothing from anywhere else.
package main

import (
	"context"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

const (
	listenAddr = ":8080"
	cacheTTL   = 5 * time.Minute
	maxNote    = 4096
	// How many notes GET /notes answers with, the most recent first.
	listLimit = 50
)

//go:embed page
var pageFiles embed.FS

// The page's own policy: everything it loads, and every request it sends,
// comes from this server.
const contentSecurityPolicy = "default-src 'self'; img-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'"

// note is one stored note, and the answer about it.
type note struct {
	ID        int64     `json:"id"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"created_at"`
	// Source is where this answer read the note from: "postgresql" or "cache".
	Source string `json:"source"`
}

type service struct {
	db         *pgxpool.Pool
	dbAddr     string
	cache      *redis.Client // nil when no cache is wired
	cacheAddr  string
	schemaMu   sync.Mutex
	schemaDone bool
	page       []byte
}

func main() {
	log.SetFlags(log.LstdFlags | log.LUTC)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()

	page, err := pageFiles.ReadFile("page/index.html")
	if err != nil {
		log.Fatal(err)
	}
	static, err := fs.Sub(pageFiles, "page")
	if err != nil {
		log.Fatal(err)
	}

	// An empty connection string makes the driver read the PG* variables.
	cfg, err := pgxpool.ParseConfig("")
	if err != nil {
		log.Fatalf("reading the PostgreSQL settings from PGHOST, PGPORT, PGUSER, PGPASSWORD and PGDATABASE: %v", err)
	}
	cfg.MaxConns = 4
	db, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		log.Fatalf("preparing the PostgreSQL connection: %v", err)
	}
	defer db.Close()
	s := &service{
		db:     db,
		dbAddr: fmt.Sprintf("%s:%d/%s", cfg.ConnConfig.Host, cfg.ConnConfig.Port, cfg.ConnConfig.Database),
		page:   page,
	}

	if host := os.Getenv("REDIS_HOST"); host != "" {
		port := os.Getenv("REDIS_PORT")
		if port == "" {
			port = "6379"
		}
		s.cacheAddr = net.JoinHostPort(host, port)
		s.cache = redis.NewClient(&redis.Options{Addr: s.cacheAddr, DialTimeout: 2 * time.Second})
		defer s.cache.Close()
	}
	log.Printf("quickstart-web: database %s, cache %s", s.dbAddr, s.cacheDescription())

	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.index)
	mux.Handle("GET /page/{file}", secured(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFileFS(w, r, static, r.PathValue("file"))
	})))
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("POST /notes", s.create)
	mux.HandleFunc("GET /notes", s.list)
	mux.HandleFunc("GET /notes/{id}", s.read)
	srv := &http.Server{Addr: listenAddr, Handler: mux, ReadHeaderTimeout: 10 * time.Second}

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

func (s *service) cacheDescription() string {
	if s.cache == nil {
		return "not wired"
	}
	return s.cacheAddr
}

// secured sets the headers the page and its files carry. The JSON answers are
// left as they are. It is this program's own: each quickstart image builds from
// its own directory and module, so the chat image's helper of the same name
// cannot be shared.
func secured(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Content-Security-Policy", contentSecurityPolicy)
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}

// ensureSchema creates the notes table on first use. The database may still be
// starting when the service does, so a failure is returned to the request and
// tried again by the next one.
func (s *service) ensureSchema(ctx context.Context) error {
	s.schemaMu.Lock()
	defer s.schemaMu.Unlock()
	if s.schemaDone {
		return nil
	}
	_, err := s.db.Exec(ctx, `CREATE TABLE IF NOT EXISTS notes (
		id         bigserial PRIMARY KEY,
		text       text NOT NULL,
		created_at timestamptz NOT NULL DEFAULT now()
	)`)
	if err == nil {
		s.schemaDone = true
	}
	return err
}

// index answers / with the page when the request prefers HTML, and with what
// the service is connected to otherwise. Both answers vary with Accept, so a
// cache between the two never hands one to the other.
func (s *service) index(w http.ResponseWriter, r *http.Request) {
	w.Header().Add("Vary", "Accept")
	if !prefersHTML(r.Header.Values("Accept")) {
		s.info(w, r)
		return
	}
	secured(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write(s.page)
	})).ServeHTTP(w, r)
}

// prefersHTML reports whether an Accept header names text/html itself with a
// higher preference than JSON gets, as a browser's header does. JSON's
// preference is the one of the most specific range matching it:
// application/json, then application/*, then */*. A missing header, curl's
// default */*, a request for application/json and a tie all get JSON.
func prefersHTML(accept []string) bool {
	html := 0.0
	jsonQ, jsonRank := 0.0, 0
	for _, field := range accept {
		for _, part := range strings.Split(field, ",") {
			mediaRange, q := parseMediaRange(part)
			rank := 0
			switch mediaRange {
			case "text/html":
				html = max(html, q)
				continue
			case "application/json":
				rank = 3
			case "application/*":
				rank = 2
			case "*/*":
				rank = 1
			default:
				continue
			}
			if rank > jsonRank || (rank == jsonRank && q > jsonQ) {
				jsonQ, jsonRank = q, rank
			}
		}
	}
	return html > jsonQ
}

// parseMediaRange reads one element of an Accept header: its media range in
// lower case and its q value, 1 when absent. A q value that is not a number
// from 0 to 1 counts as 0, so the range it qualifies is not preferred.
func parseMediaRange(part string) (string, float64) {
	params := strings.Split(part, ";")
	mediaRange := strings.ToLower(strings.TrimSpace(params[0]))
	q := 1.0
	for _, param := range params[1:] {
		name, value, ok := strings.Cut(strings.TrimSpace(param), "=")
		if !ok || !strings.EqualFold(strings.TrimSpace(name), "q") {
			continue
		}
		v, err := strconv.ParseFloat(strings.TrimSpace(value), 64)
		if err != nil || v < 0 || v > 1 {
			v = 0
		}
		q = v
	}
	return mediaRange, q
}

func (s *service) info(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"service":  "quickstart-web",
		"database": "postgresql at " + s.dbAddr,
		"cache":    s.cacheDescription(),
	})
}

func (s *service) health(w http.ResponseWriter, r *http.Request) {
	if err := s.db.Ping(r.Context()); err != nil {
		writeError(w, http.StatusServiceUnavailable, "PostgreSQL does not answer: "+err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *service) create(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, maxNote+1))
	if err != nil || len(body) == 0 || len(body) > maxNote {
		writeError(w, http.StatusBadRequest, fmt.Sprintf("send the note as the request body, 1 to %d bytes", maxNote))
		return
	}
	if err := s.ensureSchema(r.Context()); err != nil {
		writeError(w, http.StatusServiceUnavailable, "PostgreSQL is not ready: "+err.Error())
		return
	}
	n := note{Text: string(body), Source: "postgresql"}
	err = s.db.QueryRow(r.Context(),
		`INSERT INTO notes (text) VALUES ($1) RETURNING id, created_at`, n.Text).Scan(&n.ID, &n.CreatedAt)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "storing the note: "+err.Error())
		return
	}
	log.Printf("note %d stored in postgresql", n.ID)
	writeJSON(w, http.StatusCreated, n)
}

// list answers the most recent notes, read from PostgreSQL. It neither reads
// nor fills the cache, so listing the notes never changes where the next read
// of one comes from.
func (s *service) list(w http.ResponseWriter, r *http.Request) {
	if err := s.ensureSchema(r.Context()); err != nil {
		writeError(w, http.StatusServiceUnavailable, "PostgreSQL is not ready: "+err.Error())
		return
	}
	rows, err := s.db.Query(r.Context(),
		`SELECT id, text, created_at FROM notes ORDER BY id DESC LIMIT $1`, listLimit)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "listing the notes: "+err.Error())
		return
	}
	notes, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (note, error) {
		n := note{Source: "postgresql"}
		return n, row.Scan(&n.ID, &n.Text, &n.CreatedAt)
	})
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "listing the notes: "+err.Error())
		return
	}
	if notes == nil {
		notes = []note{}
	}
	log.Printf("%d notes listed from postgresql", len(notes))
	writeJSON(w, http.StatusOK, map[string][]note{"notes": notes})
}

func (s *service) read(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id < 1 {
		writeError(w, http.StatusBadRequest, "a note's id is a positive whole number")
		return
	}
	key := "quickstart-web:note:" + strconv.FormatInt(id, 10)
	if s.cache != nil {
		cached, err := s.cache.Get(r.Context(), key).Bytes()
		switch {
		case err == nil:
			var n note
			if json.Unmarshal(cached, &n) == nil {
				n.Source = "cache"
				log.Printf("note %d read from the cache", id)
				writeJSON(w, http.StatusOK, n)
				return
			}
		case !errors.Is(err, redis.Nil):
			// The cache is an optimisation: when it fails, the database answers.
			log.Printf("cache unavailable, reading note %d from postgresql: %v", id, err)
		}
	}
	if err := s.ensureSchema(r.Context()); err != nil {
		writeError(w, http.StatusServiceUnavailable, "PostgreSQL is not ready: "+err.Error())
		return
	}
	n := note{ID: id, Source: "postgresql"}
	err = s.db.QueryRow(r.Context(), `SELECT text, created_at FROM notes WHERE id = $1`, id).Scan(&n.Text, &n.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusNotFound, fmt.Sprintf("no note %d", id))
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "reading the note: "+err.Error())
		return
	}
	log.Printf("note %d read from postgresql", id)
	if s.cache != nil {
		if encoded, err := json.Marshal(n); err == nil {
			if err := s.cache.Set(r.Context(), key, encoded, cacheTTL).Err(); err != nil {
				log.Printf("caching note %d: %v", id, err)
			}
		}
	}
	writeJSON(w, http.StatusOK, n)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	_ = enc.Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
