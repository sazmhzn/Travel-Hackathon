/// Keys read from `--dart-define` at build time.
enum AppEnvKey {
  apiBaseUrl('API_BASE_URL');

  const AppEnvKey(this.value);

  final String value;
}
