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
- API base URL is owned by `lib/core/config/app_config.dart` (default
  `http://192.168.1.69:3000/api`, override with
  `--dart-define=API_BASE_URL=...`). Do not hardcode URLs elsewhere.
- UI foundation lives in `lib/core/`:
  - `core/theme/` — `AppColors` (raw) → `AppSemanticColors` (ThemeExtension,
    light+dark) → `AppTheme`; access with `context.semanticColors` /
    `context.textTheme`. Never hardcode a `Color(0x...)` in a feature.
  - `core/widgets/` — `AppButton`, `AppTextField`, `AppBanner`, `AppSnackBar`,
    `AppEmptyState`, `AppErrorState`, `AppLoading`, `AppShimmerZone`,
    `HoldToConfirmButton`, `AppSectionHeader`. Reuse before building custom.
  - `core/error/` — `Result`/`Failure` + `ApiExceptionHandler.safeApiCall`.
  - `core/extensions/`, `core/constants/text/`, `core/storage/`, `core/router/`.
- `lib/core/app_theme.dart` is a compatibility re-export of `core/theme/app_theme.dart`.
- See `docs/developer_guidelines.md` for naming and file-placement rules.

## Git

- Commit only when explicitly asked; never push unless asked.
