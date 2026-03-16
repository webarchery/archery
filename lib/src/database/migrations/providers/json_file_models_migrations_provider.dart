import 'package:archery/archery/archery.dart';

class JsonFileModelsMigrationsProvider  extends Provider{
  @override
  Future<void> boot(ServiceContainer container) async {
    await _migrateJsonFileModels();
  }
}

Future<void> _migrateJsonFileModels() async {
  await JsonFileModel.migrate<User>(constructor: User.fromJson);
  await JsonFileModel.migrate<Session>(constructor: Session.fromJson);
  await JsonFileModel.migrate<AuthSession>(constructor: AuthSession.fromJson);
}