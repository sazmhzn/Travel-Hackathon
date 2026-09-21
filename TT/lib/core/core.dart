/// Core foundation barrel: theme, extensions, widgets, error, config, storage.
///
/// Feature code may import `package:tt/core/core.dart` (or a relative path) to
/// get the shared design system in one line.
library;

export 'config/app_config.dart';
export 'config/app_env_key.dart';
export 'constants/app/enums/expedition_status.dart';
export 'constants/app/enums/user_role.dart';
export 'constants/text/app_text.dart';
export 'constants/text/date_time_text.dart';
export 'error/error.dart';
export 'extensions/context_extensions.dart';
export 'extensions/count_extensions.dart';
export 'extensions/datetime_extensions.dart';
export 'router/app_routes.dart';
export 'storage/local_storage_service.dart';
export 'storage/storage_keys.dart';
export 'theme/app_colors.dart';
export 'theme/app_semantic_colors.dart';
export 'theme/app_sizes.dart';
export 'theme/app_text_styles.dart';
export 'theme/app_theme.dart';
export 'widgets/widgets.dart';
