# Developer guidelines (Flutter app `TT/`)

Paths below are relative to `TT/lib/`.

## Before you push

- `flutter analyze lib` must pass with no errors.
- Screens must not hardcode colors, spacing or radii — use `core/theme` tokens.
- Reuse `core/widgets` before building a one-off widget.

## Layering

Feature-first, with a clean split when a feature grows:

```text
lib/
├── core/                     shared foundation (theme, widgets, error, ...)
├── features/<feature>/
│   ├── data/                 models, data sources, repository implementations
│   ├── domain/               entities, repository contracts, use cases
│   └── presentation/         pages, widgets, providers/notifiers
└── shared/presentation/      cross-feature shell widgets
```

- Presentation never talks to HTTP directly; go through a repository.
- Repositories wrap calls with `ApiExceptionHandler.safeApiCall` and return
  `Result<T>` (`Ok`/`Err`). UI switches on the result — never show raw
  exceptions.
- State is Riverpod (`AsyncNotifier` / `AsyncValue` for async screens). Avoid
  hand-rolled `_isLoading` booleans on new screens.

## Naming

`snake_case` files, `PascalCase` types, `lowerCamelCase` members. One primary
public type per file.

| If the file is… | Suffix | Example |
| --- | --- | --- |
| Screen / page | `_screen.dart` | `group_list_screen.dart` |
| Reusable widget | `_widget.dart` | `empty_state_widget.dart` |
| Bottom sheet | `_bottom_sheet.dart` | `sos_sheet.dart` |
| Provider / notifier | `_provider.dart` / `_notifier.dart` | `groups_notifier.dart` |
| Domain entity | `_entity.dart` | `expedition_entity.dart` |
| Repository contract | `_repository.dart` | `group_repository.dart` |
| Repository impl | `_repository_impl.dart` | `group_repository_impl.dart` |
| Remote data source | `_remote_data_source.dart` | `group_remote_data_source.dart` |
| Data model | `_model.dart` | `group_model.dart` |
| Request body model | `_request_model.dart` | `join_group_request_model.dart` |
| Use case | verb, no suffix | `start_expedition.dart` |
| Text constants | `_text.dart` | `emergency_text.dart` |
| Extension | `_extensions.dart` | `datetime_extensions.dart` |
| Shimmer / skeleton | `_shimmer.dart` | `groups_shimmer.dart` |

## Placement

- Theme tokens: `core/theme/`.
- Shared widgets: `core/widgets/` (only when reused across features).
- Feature widgets: `features/<feature>/presentation/widgets/`.
- Strings: `core/constants/text/<feature>_text.dart`; shared enums in
  `core/constants/app/enums/`.
- Storage keys: add to `core/storage/storage_keys.dart`, never inline.

## Design system rules

- **Colors:** read `context.semanticColors`. `danger` is reserved for real
  emergencies and destructive actions; `warning` for degraded-but-safe states
  (e.g. offline); `brand` for primary actions.
- **Radius:** chips `AppRadius.sm`, inputs/buttons `AppRadius.md`, cards
  `AppRadius.lg`, sheets `AppRadius.xl`, pills `AppRadius.full`.
- **Spacing:** use `AppSpacing`, never literal numbers.
- **Emergency vs normal:** calm teal chrome for normal flows; the danger
  language is reserved for SOS, missing members and off-route states.
- **Motion:** gate animations on `context.reduceMotion`.
- **Loading:** prefer `AppShimmerZone` mirrors over bare spinners.
