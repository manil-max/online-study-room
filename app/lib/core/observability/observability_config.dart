/// Gözlemlenebilirlik yalnız açıkça verilen derleme ayarlarıyla başlar.
///
/// DSN gizli sayılmaz; buna rağmen `env.json` repoya girmez. Varsayılan kapalı
/// olması, yerel geliştirme/test ile beta/stable kanallarının ayrılmasını sağlar.
class ObservabilityConfig {
  const ObservabilityConfig({
    required this.dsn,
    required this.environment,
    required this.release,
    required this.buildEnabled,
  });

  factory ObservabilityConfig.fromEnvironment() {
    return const ObservabilityConfig(
      dsn: String.fromEnvironment('SENTRY_DSN'),
      environment: String.fromEnvironment(
        'SENTRY_ENVIRONMENT',
        defaultValue: 'development',
      ),
      release: String.fromEnvironment(
        'SENTRY_RELEASE',
        defaultValue: 'odak-kampi@unknown',
      ),
      buildEnabled: bool.fromEnvironment('SENTRY_ENABLED'),
    );
  }

  final String dsn;
  final String environment;
  final String release;
  final bool buildEnabled;

  bool get isConfigured => buildEnabled && dsn.isNotEmpty;
}
