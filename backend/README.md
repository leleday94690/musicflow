# MusicFlow Backend

Go + MySQL API for the MusicFlow app.

## Requirements

- Go 1.24+
- MySQL 8+

## Setup

```bash
mysql -u<user> -p < migrations/001_init.sql
```

## Run

```bash
cp .env.example .env.local
make dev
```

Edit `.env.local` with your local MySQL credentials before running `make dev`.
`MYSQL_DSN` is required. `.env.local` is ignored by git.

For a first deploy, set these values before the first backend start:

- `MUSICFLOW_TOKEN_SECRET`: a long random secret used to sign login tokens.
- `MUSICFLOW_ADMIN_USERNAME`: administrator username, defaults to `admin`.
- `MUSICFLOW_ADMIN_PASSWORD`: when set, the backend creates or resets that administrator account.
- `MUSICFLOW_ADMIN_NAME`: administrator display name.

Leave `MUSICFLOW_DEMO_PASSWORD` empty in production. If it is set, a non-admin `normal` demo user is created.

You can also run without `.env.local` by exporting the variables manually:

```bash
export MYSQL_DSN='musicflow_user:change_me@tcp(127.0.0.1:3306)/musicflow?charset=utf8mb4&parseTime=true&loc=Local'
export APP_CORS_ORIGINS='http://localhost:3000,http://127.0.0.1:3000,http://localhost:8080,http://127.0.0.1:8080'
export MUSICFLOW_TOKEN_SECRET='change_this_to_a_long_random_secret'
export MUSICFLOW_ADMIN_PASSWORD='set_a_strong_password_once'
go run ./cmd/server
```

## APIs

- `GET /health`
- `GET /api/songs?limit=20`
- `GET /api/search?q=keyword`
- `GET /api/playlists`
- `GET /api/playlists/{id}`
- `GET /api/profile`
- `GET /api/downloads`
