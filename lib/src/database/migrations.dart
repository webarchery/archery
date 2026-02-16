import 'package:archery/archery/archery.dart';

/// Registers and migrates built-in models for the JSON file driver.
///
/// This wires constructor registries and creates backing storage for:
/// - [User]
/// - [Session]
/// - [AuthSession]
Future<void> migrateJsonFileModels() async {
  await JsonFileModel.migrate<User>(constructor: User.fromJson);
  await JsonFileModel.migrate<Session>(constructor: Session.fromJson);
  await JsonFileModel.migrate<AuthSession>(constructor: AuthSession.fromJson);
}

/// Registers and migrates built-in models for the S3 JSON file driver.
///
/// This wires constructor registries and creates backing storage for:
/// - [User]
/// - [Session]
/// - [AuthSession]

Future<void> migrateS3JsonFileModels() async {
  await S3JsonFileModel.migrate<User>(constructor: User.fromJson);
  await S3JsonFileModel.migrate<Session>(constructor: Session.fromJson);
  await S3JsonFileModel.migrate<AuthSession>(constructor: AuthSession.fromJson);

}


/// Registers and migrates built-in models for the Postgres driver.
///
/// This wires constructor registries and creates tables for:
/// - [User]
/// - [Session]
/// - [AuthSession]
Future<void> migratePostgresModels() async {

  await PostgresModel.migrate<User>(constructor: User.fromJson, columnDefinitions: User.columnDefinitions);
  await PostgresModel.migrate<Session>(constructor: Session.fromJson, columnDefinitions: Session.columnDefinitions);
  await PostgresModel.migrate<AuthSession>(constructor: AuthSession.fromJson, columnDefinitions: AuthSession.columnDefinitions);

}

/// Registers and migrates built-in models for the SQLite driver.
///
/// This wires constructor registries and creates tables for:
/// - [User]
/// - [Session]
/// - [AuthSession]
Future<void> migrateSQLiteModels() async {
  await SQLiteModel.migrate<User>(constructor: User.fromJson, columnDefinitions: User.columnDefinitions);
  await SQLiteModel.migrate<Session>(constructor: Session.fromJson, columnDefinitions: Session.columnDefinitions);
  await SQLiteModel.migrate<AuthSession>(constructor: AuthSession.fromJson, columnDefinitions: AuthSession.columnDefinitions);
}
