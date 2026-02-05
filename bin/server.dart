import 'package:archery/archery/archery.dart';
import 'package:archery/src/database/migrations.dart';
import 'package:archery/src/http/routes/api.dart';
import 'package:archery/src/http/routes/web.dart';

Future<void> main(List<String> args) async {
  // init application
  final app = App();
  app.setKeys();

  // parse config and attach to app
  final config = await AppConfig.create();
  app.container.singleton<AppConfig>(factory: (_, [_]) => config, eager: true);

  await app.boot();

  // db migrations
  await migrateJsonFileModels();
  await migrateSQLiteModels();

  // router
  final router = app.make<Router>();
  authRoutes(router);
  webRoutes(router);
  apiRoutes(router);

  // pass router to kernel
  final kernel = AppKernel(
    router: router,
    middleware: [
      VerifyCsrfToken.middleware,
    ],
  );

  // make sure there's a bag for sessions
  app.container.bindInstance<List<Session>>([]);
  app.container.bindInstance<List<AuthSession>>([]);

  // init server with static files
  final port = config.get('server.port') ?? 5502;
  final staticFilesServer = app.make<StaticFilesServer>();

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
    await app.shutdown().then(
      (_) => print("App has shut down from a server initialization error"),
    );
  }
}


