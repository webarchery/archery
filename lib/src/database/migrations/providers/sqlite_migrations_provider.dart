import 'package:archery/archery/archery.dart';

/// Provider that runs SQLite model migrations during application boot.
///
/// Registering this provider ensures the framework's SQLite-backed models are
/// migrated before they are used by the application.
///
/// Example:
/// ```dart
/// final provider = SqliteMigrationsProvider();
/// await provider.boot(App().container);
class SqliteMigrationsProvider extends Provider {
  /// Boots the provider and executes all registered SQLite model migrations.
  ///
  /// Example:
  /// ```dart
  /// await SqliteMigrationsProvider().boot(container);
  /// ```
  @override
  Future<void> boot(ServiceContainer container) async {
    await _migrateSQLiteModels();
  }
}


/// Runs SQLite migrations for the framework's built-in models.
///
/// This function registers and migrates the default SQLite-backed models used
/// by the framework, including users, roles, queue jobs, guest sessions, and
/// auth sessions.
///
/// Current migrations:
/// - [User]
/// - [Role]
/// - [QueueJob]
/// - [Session]
/// - [AuthSession]
///
/// Example:
/// ```dart
/// await _migrateSQLiteModels();
/// ```
Future<void> _migrateSQLiteModels() async {
  await SQLiteModel.migrate<User>(
    constructor: User.fromJson,
    columnDefinitions: User.columnDefinitions,
  );

  await SQLiteModel.migrate<Role>(
    constructor: Role.fromJson,
    columnDefinitions: Role.columnDefinitions,
  );

  await SQLiteModel.migrate<QueueJob>(
    constructor: QueueJob.fromJson,
    columnDefinitions: QueueJob.columnDefinitions,
  );
  await SQLiteModel.migrate<Session>(
    constructor: Session.fromJson,
    columnDefinitions: Session.columnDefinitions,
  );
  await SQLiteModel.migrate<AuthSession>(
    constructor: AuthSession.fromJson,
    columnDefinitions: AuthSession.columnDefinitions,
  );
}

