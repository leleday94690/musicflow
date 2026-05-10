# MusicFlow Frontend

Flutter client for MusicFlow.

## Run

```bash
cp .env.example .env.local
make dev
```

## Configuration

`MUSICFLOW_API_BASE_URL` controls the backend API base URL. If it is not provided, the app uses `http://127.0.0.1:8080`.

Edit `.env.local` if your backend is not running at `http://127.0.0.1:8080`.
`.env.local` is ignored by git.

You can also run with a different device:

```bash
make dev FLUTTER_DEVICE=chrome
```
