import 'package:archery/archery/archery.dart';

enum TodoStatus {

  created("created"),
  working("working"),
  complete("complete"),
  archived("archived");

  final String progress;

  const TodoStatus(this.progress);

  static TodoStatus fromString(String progress) {
    return TodoStatus.values.firstWhere((status) => status.progress == progress.toLowerCase(), orElse: () => TodoStatus.created);
  }
}


class Todo extends Model {

  late String task;
  TodoStatus status = TodoStatus.created;

  Todo({required this.task}) : super.fromJson({});

  Todo.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    if (json['task'] != null && json['task'] is String) {
      task = json['task'];
    }
    if (json['progress'] != null && json['progress'] is String) {
      status = TodoStatus.fromString(json['progress']);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "uuid": uuid,
      'task': task,
      'progress': "${status.progress[0].toUpperCase()}${status.progress.substring(1)}",
      "created_at": createdAt?.toIso8601String(),
      "updated_at": updatedAt?.toIso8601String(),
    };
  }

  @override
  Map<String, dynamic> toMetaJson() {
    return {
      "id": id,
      "uuid": uuid,
      'task': task,
      'progress': "${status.progress[0].toUpperCase()}${status.progress.substring(1)}",
      "created_at": createdAt?.toIso8601String(),
      "updated_at": updatedAt?.toIso8601String(),
    };
  }

  static Map<String, String> columnDefinitions = {'task': 'TEXT NOT NULL', 'progress': 'TEXT NOT NULL'};

  @override
  Future<bool> save({Disk? disk}) async => await Model.saveInstance<Todo>(instance: this, disk: disk ?? this.disk);

  @override
  Future<bool> delete({Disk? disk}) async => await Model.deleteInstance<Todo>(instance: this, disk: disk ?? this.disk);

  @override
  Future<bool> update({Disk? disk}) async => await Model.updateInstance<Todo>(instance: this, withJson: toMetaJson(), disk: disk ?? this.disk);
}

void todoRoutes(Router router) {
  router.group(prefix: "/todos", routes: () {

      router.get("/", middleware: [Auth.middleware], (request) async {
        final todos = await Model.all<Todo>();
        todos.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
        return request.view("todos.index", {
          'todos': [...todos].map((todo) => todo.toJson()).toList(),
        });
      });

      router.post("/", middleware: [Auth.middleware], (request) async {
        final form = request.form();
        final task = await form.input('task');
        if (task != null && task.isNotEmpty && task.toString().length <= 255) {
          final todo = Todo(task: task.toString().trim());
          await todo.save();
          request.redirectBack();
        } else {
          request.redirectBack();
        }
      });

      router.get("/{uuid:string}", middleware: [Auth.middleware], (request) async {
        try {
          final uuid = RouteParams.get<String>("uuid");
          final todo = await Model.firstWhere<Todo>(field: "uuid", value: uuid!);
          if (todo == null) return request.notFound();
          return request.json(todo.toJson());
        } catch (e) {
          return request.notFound();
        }
      });

      router.delete("/{uuid:string}", middleware: [Auth.middleware], (request) async {
        try {
          final uuid = RouteParams.get<String>("uuid");
          final todo = await Model.firstWhere<Todo>(field: "uuid", value: uuid);
          await todo?.delete();
          request.redirectBack();
        } catch (e) {
          return request.notFound();
        }
      });

      router.patch("/truncate", middleware: [Auth.middleware], (request) async {
        try {
          await Model.truncate<Todo>();
          request.redirectBack();
        } catch (e) {
          return request.notFound();
        }
      });
    },
  );
}
