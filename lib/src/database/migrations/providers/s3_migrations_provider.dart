import 'package:archery/archery/archery.dart';

class S3MigrationsProvider  extends Provider{
  @override
  Future<void> boot(ServiceContainer container) async {
    await _migrateS3JsonFileModels();
  }
}


Future<void> _migrateS3JsonFileModels() async {
  await S3JsonFileModel.migrate<User>(constructor: User.fromJson);
  await S3JsonFileModel.migrate<Session>(constructor: Session.fromJson);
  await S3JsonFileModel.migrate<AuthSession>(constructor: AuthSession.fromJson);
}