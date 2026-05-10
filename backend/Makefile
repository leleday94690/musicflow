.PHONY: dev test

ENV_FILE ?= .env.local

dev:
	@if [ -f "$(ENV_FILE)" ]; then \
		set -a; . ./$(ENV_FILE); set +a; \
		if [ -z "$$MYSQL_DSN" ]; then echo "MYSQL_DSN is required. Please set it in $(ENV_FILE)."; exit 1; fi; \
		go run ./cmd/server; \
	else \
		if [ -z "$$MYSQL_DSN" ]; then echo "MYSQL_DSN is required. Create $(ENV_FILE) from .env.example or export MYSQL_DSN."; exit 1; fi; \
		go run ./cmd/server; \
	fi

test:
	go test ./...
