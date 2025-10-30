import 'package:archery/archery/archery.dart';

Future<void> migrateJsonFileModels() async {
  JsonFileModel.migrate<User>(constructor: User.fromJson);
}


Future<void> migrateSQLiteModels() async {
  SQLiteModel.migrate<User>(constructor: User.fromJson, columnDefinitions: User.columnDefinitions);
}


