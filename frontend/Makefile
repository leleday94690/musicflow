.PHONY: dev analyze test

ENV_FILE ?= .env.local
FLUTTER_DEVICE ?= macos

dev:
	@if [ -f "$(ENV_FILE)" ]; then \
		set -a; . ./$(ENV_FILE); set +a; \
		flutter run -d $(FLUTTER_DEVICE) --dart-define=MUSICFLOW_API_BASE_URL=$${MUSICFLOW_API_BASE_URL:-http://127.0.0.1:8080}; \
	else \
		flutter run -d $(FLUTTER_DEVICE) --dart-define=MUSICFLOW_API_BASE_URL=$${MUSICFLOW_API_BASE_URL:-http://127.0.0.1:8080}; \
	fi

analyze:
	flutter analyze

test:
	flutter test
