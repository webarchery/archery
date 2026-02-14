// SPDX-FileCopyrightText: 2025 Kwame, III <webarcherydev@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// https://webarchery.dev

import 'package:archery/archery/archery.dart';
import 'package:postgres/postgres.dart';

/// Enum representing the lifecycle status of the [App] instance.
enum AppStatus {
  /// The application is in the process of initializing.
  initializing,

  /// The application is booting up and loading providers.
  booting,

  /// The application is fully booted and ready to handle requests.
  ready,

  /// An error occurred during boot or runtime.
  error,

  /// The application is in the process of shutting down.
  shuttingDown,
}

/// The main application class that serves as a singleton service container
/// and lifecycle manager for the Archery framework.
///
/// Provides dependency injection, provider registration, boot sequence,
/// and configuration management.
class App {
  /// The current version of the application.
  static final String version = "1.3.1";

  /// Private constructor to enforce singleton pattern.
  App._internal();

  /// List of registered service providers.
  final List<Provider> _providers = [];

  /// Callbacks to be executed once the app has successfully booted.
  final List<void Function()> _bootedCallbacks = [];

  /// Current status of the application lifecycle.
  AppStatus status = AppStatus.initializing;

  /// The singleton instance of [App].
  static final App _instance = App._internal();

  /// Factory constructor returning the singleton instance.
  factory App() => _instance;

  /// Root service container for dependency injection.
  final ServiceContainer container = Container.root();

  /// Registers a single [Provider] with the application.
  ///
  /// Throws [ProviderException.duplicateRegistration] if the provider is already registered.
  ///
  /// The provider's [Provider.register] method is immediately called to bind services.
  void register(Provider provider) {
    if (_providers.contains(provider)) {
      throw ProviderException.duplicateRegistration(type: provider.runtimeType);
    }
    _providers.add(provider);
    provider.register(container);
  }

  /// Registers a group of [Provider]s under a logical [groupName].
  ///
  /// Catches and wraps individual registration errors with [ProviderException.unregistered].
  void registerGroup(String groupName, List<Provider> providers) {
    for (final provider in providers) {
      try {
        register(provider);
      } catch (e, stack) {
        throw ProviderException.unregistered(type: provider.runtimeType, trace: stack);
      }
    }
  }

  /// Adds a callback to be executed when the application has finished booting.
  ///
  /// Callbacks are invoked in the order they were registered.
  void onBooted(void Function() callback) {
    _bootedCallbacks.add(callback);
  }

  /// Initiates graceful shutdown of the application.
  ///
  /// Currently logs shutdown message. Extend to close DB connections,
  /// stop servers, flush caches, etc.
  Future<void> shutdown() async {
    status = AppStatus.shuttingDown;
    print('Shutting down...');
    // TODO: Implement cleanup (close DB, stop HTTP server, etc.)
  }

  /// Generates a secure random 32-byte key encoded in URL-safe base64.
  ///
  /// Used for application encryption key, session secrets, etc.
  static String generateKey() {
    return base64Url.encode(List.generate(32, (i) => Random.secure().nextInt(256)));
  }

  /// Ensures `lib/src/config/app.json` exists and populates it with default config.
  ///
  /// If [reset] is `true`, overwrites existing config.
  /// Otherwise, only writes if file is missing or empty.
  ///
  /// Sets:
  /// - `name`, `version`, `timestamp`
  /// - Secure `key` via [generateKey]
  /// - Unique `id` via UUID v4
  /// - `debug: true`
  void setKeys({bool reset = false}) {
    final file = File('lib/src/config/app.json');

    // Ensure file exists
    if (!file.existsSync()) {
      file.createSync(recursive: true);
      file.writeAsStringSync('{}');
    }

    String content = file.readAsStringSync();

    // Skip if content exists and not resetting
    if ((content.isNotEmpty && content != "{}") && !reset) return;

    final config = <String, dynamic>{"name": "Archery Web Application", "version": version, "timestamp": DateTime.now().toUtc().toIso8601String(), "key": generateKey(), "id": Uuid().v4(), "debug": true};

    file.writeAsStringSync(json.encode(config));
  }
}

extension Boot on App {
  /// Boots the application by initializing core services and providers.
  ///
  /// Sets up:
  /// - Default [Router]
  /// - [TemplateEngine] with views and public paths
  /// - [StaticFilesServer]
  /// - [Uuid] generator
  /// - SQLite [Database] in `lib/src/storage/database.sqlite`
  ///
  /// Then boots all registered providers and triggers `onBooted` callbacks.
  ///
  /// Sets [status] to [AppStatus.ready] on success, or [AppStatus.error] on failure.
  Future<void> boot() async {
    status = AppStatus.booting;

    // Default Router
    final router = Router();
    container.bindInstance<Router>(router);

    // Default View Engine
    final settings = {"viewsPath": 'lib/src/http/views', "publicPath": 'lib/src/http/public'};
    final engine = TemplateEngine(viewsDirectory: settings['viewsPath']!, publicDirectory: settings['publicPath']!);

    // Enable caching for performance
    engine.shouldCache = true; // Enabled by default for performance recommendation
    // engine.shouldCache = config?.get('view.cache', true) ?? true;
    container.bindInstance<TemplateEngine>(engine);

    // Default Static Files Server
    final staticFilesServer = StaticFilesServer();
    container.bindInstance<StaticFilesServer>(staticFilesServer);

    // Default UUID Generator
    final Uuid uuid = Uuid();
    container.bindInstance<Uuid>(uuid);

    // Default SQLite DB
    final Directory dir = Directory("lib/src/storage");
    final file = File("${dir.absolute.path}/database.sqlite");
    final SQLiteDatabase sqliteDatabase = await databaseFactoryFfi.openDatabase(
      file.absolute.path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Placeholder for database migrations
        },
      ),
    );
    container.singleton<SQLiteDatabase>(factory: (_, [_]) => sqliteDatabase, eager: true);

    // Default Postgres DB
    // Todo - uncomment to init postgres when you config is set

    // try {
    //   final postgresConnection = await PostgresDatabase.open(
    //     Endpoint(host: config.get('db.pgsql.host', ''), database: config.get('db.pgsql.database', ''), username: config.get('db.pgsql.username', ''), password: config.get('db.pgsql.password', '')),
    //     // The postgres server hosted locally doesn't have SSL by default. If you're
    //     // accessing a postgres server over the Internet, the server should support
    //     // SSL and you should swap out the mode with `SslMode.verifyFull`.
    //     settings: ConnectionSettings(sslMode: SslMode.disable),
    //   );
    //
    //   container.bindInstance<PostgresDatabase>(postgresConnection);
    //
    // } catch (e, s) {
    //   App().archeryLogger.error("Postgres DB Init Error", {"origin": "App.boot()", "error": e.toString(), "stack": config.get('app.debug') != null && config.get('app.debug') == true ? s.toString() : ''});
    // }

    await container.initialize();

    try {
      // Boot all registered providers
      for (final provider in _providers) {
        try {
          await provider.boot(container);
        } catch (e, stack) {
          throw ProviderException.unbooted(type: provider.runtimeType, trace: stack);
        }
      }

      // Execute post-boot callbacks
      for (final callback in _bootedCallbacks) {
        callback();
      }

      status = AppStatus.ready;
    } catch (e, stack) {
      status = AppStatus.error;
      print('[App Boot Error] $e\n$stack');
      rethrow; // Optional: allow external handling
    }
  }
}

/// Extension on [App] providing syntactic sugar for dependency resolution and binding.
extension ContainerOperations on App {
  /// Resolves a registered instance of type [T].
  ///
  /// Equivalent to [make].
  T resolve<T>() => resolveInstance<T>();

  /// Alias for [resolve]. Resolves a registered instance.
  T make<T>() => resolveInstance<T>();

  /// Resolves an instance of type [T] from the container.
  ///
  /// Throws if not found.
  T resolveInstance<T>() {
    return container.make<T>();
  }

  /// Attempts to resolve an instance of type [T]. Returns `null` if not found.
  T? tryResolve<T>() => tryResolveInstance<T>();

  /// Alias for [tryResolve].
  T? tryMake<T>() => tryResolveInstance<T>();

  /// Safely attempts to resolve an instance. Returns `null` on failure.
  T? tryResolveInstance<T>() {
    return container.tryMake<T>();
  }

  /// Binds a concrete [instance] to type [T] in the container.
  ///
  /// Alias for [bindInstance].
  void bind<T>(T instance) => bindInstance<T>(instance);

  /// Registers a singleton [instance] of type [T].
  void bindInstance<T>(T instance) {
    container.bindInstance<T>(instance);
  }
}

extension GetConfig on App {
  AppConfig get config => container.make<AppConfig>();
}

extension GetLoggers on App {
  Logger get archeryLogger => Logger(
    transports: [config.get('app.debug') != null && config.get('app.debug') == true ? ConsoleTransport(formatJson: true) : LogFileTransport(filePath: 'lib/src/storage/logs/archery.log')],
    context: {"logger": "Archery Framework Logger"},
  );

  /// Global Loggers for easy messaging
  Logger get fileLogger => Logger(
    transports: [LogFileTransport(filePath: 'lib/src/storage/logs/archery.log')],
    context: {"logger": "App().fileLogger"},
  );

  Logger get consoleLogger => Logger(transports: [ConsoleTransport(formatJson: true)], context: {"logger": "App().consoleLogger"});

  Logger get consoleFileLogger => Logger(
    transports: [
      LogFileTransport(filePath: 'lib/src/storage/logs/archery.log'),
      ConsoleTransport(formatJson: true),
    ],
    context: {"logger": "App().consoleFileLogger"},
  );
}

extension CurrentRequest on App {
  HttpRequest get request => container.make<HttpRequest>();
}
