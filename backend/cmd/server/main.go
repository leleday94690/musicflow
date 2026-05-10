package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	_ "github.com/go-sql-driver/mysql"

	"musicflow-backend/internal/config"
	"musicflow-backend/internal/httpapi"
	"musicflow-backend/internal/repository"
)

func main() {
	cfg := config.Load()
	if cfg.MySQLDSN == "" {
		log.Fatal("MYSQL_DSN is required")
	}
	tokenSecret := strings.TrimSpace(os.Getenv("MUSICFLOW_TOKEN_SECRET"))
	if tokenSecret == "" || tokenSecret == "change_this_to_a_long_random_secret" {
		log.Print("WARNING: MUSICFLOW_TOKEN_SECRET is not set to a production secret")
	}

	db, err := sql.Open("mysql", cfg.MySQLDSN)
	if err != nil {
		log.Fatalf("open mysql: %v", err)
	}
	defer db.Close()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(pingCtx); err != nil {
		log.Fatalf("ping mysql: %v", err)
	}

	repo := repository.New(db)
	if err := repo.EnsureSchema(ctx); err != nil {
		log.Fatalf("ensure schema: %v", err)
	}
	if err := repo.EnsureSongHeatStats(ctx); err != nil {
		log.Fatalf("ensure song heat stats: %v", err)
	}

	server := &http.Server{
		Addr:              cfg.Addr,
		Handler:           httpapi.NewServer(repo, cfg.AllowedOrigins, cfg.UpdateManifestPath).Routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("musicflow api listening on %s", cfg.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()
	go runSongHeatStatsScheduler(ctx, repo)

	<-ctx.Done()

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}

func runSongHeatStatsScheduler(ctx context.Context, repo *repository.Repository) {
	location, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		log.Printf("load Asia/Shanghai location: %v", err)
		location = time.Local
	}
	for {
		now := time.Now().In(location)
		next := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, location)
		timer := time.NewTimer(time.Until(next))
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
			refreshCtx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
			if err := repo.RefreshSongHeatStats(refreshCtx); err != nil {
				log.Printf("refresh song heat stats: %v", err)
			}
			cancel()
		}
	}
}
