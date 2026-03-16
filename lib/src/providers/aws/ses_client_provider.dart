import 'package:archery/archery/archery.dart';
/// Provider that registers a configured [SesClient] in the service container.
///
/// This provider reads AWS SES configuration from `env.aws`, constructs a
/// [SesClient], and binds it into the container for later resolution.
///
/// If initialization fails, the error is logged with a configuration hint.
///
/// Example:
/// ```dart
/// final provider = SesClientProvider();
/// await provider.register(App().container);
/// ```
class SesClientProvider extends Provider {
  /// Registers the application's [SesClient] instance.
  ///
  /// Behavior:
  /// - loads SES config from `App().config.get('env.aws')`
  /// - builds a [SesConfig] from the config map
  /// - creates a [SesClient]
  /// - binds the client instance into the [ServiceContainer]
  ///
  /// On failure, an initialization error is written to the Archery logger with
  /// a hint about creating `config/env.json` or disabling the provider.
  ///
  /// Example:
  /// ```dart
  /// final container = App().container;
  /// await SesClientProvider().register(container);
  ///
  /// final ses = container.make<SesClient>();
  /// ```
  @override
  Future<void> register(ServiceContainer container) async {
    try {
      final sesConfig = SesConfig.fromMap(App().config.get('env.aws'));
      final sesClient = SesClient(sesConfig, debug: true);

      container.bindInstance<SesClient>(sesClient);
    } catch (e, s) {
      await App().archeryLogger.error('SES Client Init Error', {
        "error": e.toString(),
        "stack": s.toString(),
        "hint": "create env.json in config folder, and add aws credentials, or comment out.",
      });
    }
  }
}
