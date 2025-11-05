import 'package:archery/archery/archery.dart';

Future<void> migrateJsonFileModels() async {
  await JsonFileModel.migrate<User>(constructor: User.fromJson);
}

Future<void> migrateSQLiteModels() async {
  await SQLiteModel.migrate<User>(
    constructor: User.fromJson,
    columnDefinitions: User.columnDefinitions,
  );
}
