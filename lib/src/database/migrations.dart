import 'package:archery/archery/archery.dart';
import '../apps/todos.dart';

Future<void> migrateJsonFileModels() async {
  await JsonFileModel.migrate<User>(constructor: User.fromJson);
  await JsonFileModel.migrate<Session>(constructor: Session.fromJson);
  await JsonFileModel.migrate<AuthSession>(constructor: AuthSession.fromJson);
  await JsonFileModel.migrate<Todo>(constructor: Todo.fromJson);
}

Future<void> migrateSQLiteModels() async {
  await SQLiteModel.migrate<User>(constructor: User.fromJson, columnDefinitions: User.columnDefinitions);

  await SQLiteModel.migrate<Session>(constructor: Session.fromJson, columnDefinitions: Session.columnDefinitions);
  await SQLiteModel.migrate<AuthSession>(constructor: AuthSession.fromJson, columnDefinitions: AuthSession.columnDefinitions);

  await SQLiteModel.migrate<Todo>(constructor: Todo.fromJson, columnDefinitions: Todo.columnDefinitions);
}
