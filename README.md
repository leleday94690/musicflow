# MusicFlow

MusicFlow is a Flutter client with a Go + MySQL backend for managing and playing a personal music library.

## Local Run

Backend:

```bash
cd backend
cp .env.example .env.local
make dev
```

Frontend:

```bash
cd frontend
cp .env.example .env.local
make dev
```

## First Deploy Checklist

- Run `backend/migrations/001_init.sql` on MySQL 8+.
- Set `MYSQL_DSN`, `APP_CORS_ORIGINS`, and a long random `MUSICFLOW_TOKEN_SECRET`.
- Set `MUSICFLOW_ADMIN_PASSWORD` once to create or reset the administrator account.
- Leave `MUSICFLOW_DEMO_PASSWORD` empty for production.
- Put the backend behind HTTPS and only allow trusted frontend origins in `APP_CORS_ORIGINS`.
- Back up MySQL and `backend/storage/music` regularly.

## Production Notes

The current backend can stream local audio files directly. This is fine for small deployments, but a public deployment with many users should move audio files to object storage and CDN, then let the API return authorized playback URLs.

Local import reads paths from the backend host. For public web/mobile users, add a real upload endpoint before relying on local import as a user-facing feature.

Music ownership is split into two scopes:

- Public library songs are created by administrators and appear in "全部歌曲" for every user.
- Private songs are created when a normal user downloads from network search; they stay in that user's download space and do not pollute the public library.
