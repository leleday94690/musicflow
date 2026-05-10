package config

import (
	"os"
	"strings"
)

type Config struct {
	Addr               string
	MySQLDSN           string
	AllowedOrigins     []string
	UpdateManifestPath string
}

func Load() Config {
	addr := os.Getenv("APP_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	dsn := os.Getenv("MYSQL_DSN")
	origins := splitCSV(os.Getenv("APP_CORS_ORIGINS"))
	updateManifestPath := strings.TrimSpace(os.Getenv("MUSICFLOW_UPDATE_MANIFEST"))
	if updateManifestPath == "" {
		updateManifestPath = "/opt/musicflow/releases/manifest.json"
	}

	return Config{
		Addr:               addr,
		MySQLDSN:           dsn,
		AllowedOrigins:     origins,
		UpdateManifestPath: updateManifestPath,
	}
}

func splitCSV(value string) []string {
	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		item := strings.TrimSpace(part)
		if item != "" {
			result = append(result, item)
		}
	}
	return result
}
