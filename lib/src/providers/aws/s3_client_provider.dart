import 'package:archery/archery/archery.dart';

/// Provider that registers a configured [S3Client] in the service container.
///
/// This provider reads AWS configuration from `env.aws`, constructs an
/// [S3Client], and binds it as a singleton-style instance for later
/// resolution.
///
/// If configuration or initialization fails, the error is written to the
/// Archery logger with a setup hint.
///
/// Example:
/// ```dart
/// final provider = S3ClientProvider();
/// await provider.register(App().container);
/// ```
base class S3ClientProvider extends Provider {

  /// Registers the application's [S3Client] instance.
  ///
  /// Behavior:
  /// - loads AWS config from `App().config.get('env.aws')`
  /// - builds an [S3Config] from the config map
  /// - creates an [S3Client]
  /// - binds the client instance into the [ServiceContainer]
  ///
  /// On failure, an initialization error is logged with a hint about creating
  /// `config/env.json` or disabling the provider.
  ///
  /// Example:
  /// ```dart
  /// final container = App().container;
  /// await S3ClientProvider().register(container);
  ///
  /// final s3 = container.make<S3Client>();
  /// ```
  @override
  Future<void> register(ServiceContainer container) async {
    try {
      final s3Config = S3Config.fromMap(App().config.get('env.aws'));
      final s3Client = S3Client(s3Config, debug: true);
      container.bindInstance<S3Client>(s3Client);
    } catch (e, s) {
      await App().archeryLogger.error('S3 Client Init Error', {
        "error": e.toString(),
        "stack": s.toString(),
        "hint":
            "create env.json in config folder, and add aws credentials, or comment out.",
      });
    }
  }
}
