# WhiteMountain agent notes

## Backend (`tt backend/tt`)

The backend runs in Docker (`travel_api` container, port 3000) and does **not**
hot-reload. After ANY change under `tt backend/tt`, always rebuild and restart
before considering the task done:

```powershell
docker compose up -d --build api
```

This rebuilds the `tt-api` image from `src/` and recreates the `travel_api`
container. Migrations in `src/database/migrations/*.sql` run automatically on
startup, so a rebuild also applies new migrations.

Verify after rebuilding:

```powershell
curl.exe -s http://localhost:3000/health
```

## Flutter app (`TT`)

- Run `flutter analyze lib` after changes.
- API base URL defaults to `http://192.168.110.11:3000/api`
  (override with `--dart-define=API_BASE_URL=...`).

## Git

- Commit only when explicitly asked; never push unless asked.
