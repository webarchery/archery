import 'package:archery/archery/archery.dart';
import 'package:archery/src/apps/todos.dart';
import 'package:archery/src/database/migrations.dart';
import 'package:archery/src/http/routes/api.dart';
import 'package:archery/src/http/routes/web.dart';

Future<void> main(List<String> args) async {
  final app = App();
  app.setKeys();

  final config = await AppConfig.create();
  app.container.singleton<AppConfig>(factory: (_, [_]) => config, eager: true);

  await app.boot();

  await migrateJsonFileModels();
  await migrateSQLiteModels();

  // final user = await Model.create<User>(fromJson: { "name": "Kwame III", "email": "lucius.sinna@gmail.com", "password": "password"});

  // if(user != null) {
  //   await AuthSession.login(email: user.email, password: user.password!);
  // }



  final router = app.make<Router>();
  authRoutes(router);
  webRoutes(router);
  apiRoutes(router);
  todoRoutes(router);


  final kernel = AppKernel(router: router);

  final port = config.get('server.port') ?? 8080;
  final staticFilesServer = app.make<StaticFilesServer>();
  print("Before registration");
  print(app.container.listRegistrations());
  print("=====================");


  //
  //
  // app.container.bindInstance<int>(2, name: "myInt");
  // print(router.listRoutes());
  //
  // print("After registration");
  // print(app.container.listRegistrations());
  // print("=====================");
  //
  //
  // print("After dispose");
  // await app.container.disposeBinding<int>(name: "myInt");
  // print(app.container.listRegistrations());
  // print("=====================");
  //

  app.container.bindInstance<List<AuthSession>>([]);





  try {
    HttpServer.bind(InternetAddress.loopbackIPv4, port).then((server) async {
      server.autoCompress = config.get('server.compress', true);

      print('🔥 Archery server running at http://localhost:$port');

      await for (HttpRequest request in server) {
        if (await staticFilesServer.tryServe(request)) continue;
        kernel.handle(request);

      }
    });
  } catch (e, stack) {
    print("Error booting server: $e\n$stack");
    await app.shutdown().then((_) => print("App has shut down from a server initialization error"));
  }
}
