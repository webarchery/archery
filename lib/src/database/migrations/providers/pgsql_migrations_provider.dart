import 'package:archery/archery/archery.dart';

class PgsqlMigrationsProvider  extends Provider{

  @override
  Future<void> boot(ServiceContainer container) async {
    await _migratePostgresModels();
  }
}

Future<void> _migratePostgresModels() async {
  await PostgresModel.migrate<User>(
    constructor: User.fromJson,
    columnDefinitions: User.columnDefinitions,
  );

  await PostgresModel.migrate<Role>(
    constructor: Role.fromJson,
    columnDefinitions: Role.columnDefinitions,
  );

  await PostgresModel.migrate<QueueJob>(
    constructor: QueueJob.fromJson,
    columnDefinitions: QueueJob.columnDefinitions,
  );
  await PostgresModel.migrate<Session>(
    constructor: Session.fromJson,
    columnDefinitions: Session.columnDefinitions,
  );
  await PostgresModel.migrate<AuthSession>(
    constructor: AuthSession.fromJson,
    columnDefinitions: AuthSession.columnDefinitions,
  );
}