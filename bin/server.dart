import 'package:archery/archery/archery.dart';
import 'package:archery/src/database/migrations.dart';
import 'package:archery/src/http/routes/api.dart';
import 'package:archery/src/http/routes/web.dart';

Future<void> main(List<String> args) async {
  // init application
  final app = App();
  await App().container.initialize();
  app.setKeys();

  // parse config folder and attach to container
  final config = await AppConfig.create();
  app.container.singleton<AppConfig>(factory: (_, [_]) => config, eager: true);

  app.registerGroup("globals", [
    // uncomment when you have s3 keys in config
    // S3ClientProvider(),
  ]);

  await app.boot().then((_) async {
    /// db migrations
    /// [Model.defaultDisk] is set to .sqlite
    // run these when you are sure you have them in place

    // await migrateS3JsonFileModels();
    // await migratePostgresModels();

    // these files are auto-created for you
    // lib/src/storage/json_file_models
    await migrateJsonFileModels();
    // lib/src/storage/database.sqlite
    await migrateSQLiteModels();

    // make sure there's a bag for sessions
    app.container.bindInstance<List<Session>>([]);
    app.container.bindInstance<List<AuthSession>>([]);
  });

  // HTTP Server
  // ----------------

  // routes
  final router = app.make<Router>();
  authRoutes(router);
  webRoutes(router);
  apiRoutes(router);

  // pass router to kernel
  final kernel = AppKernel(
    router: router,
    middleware: [CorsMiddleware.middleware],
  );

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
    App().archeryLogger.error("Error booting server", {
      "error": e.toString(),
      "stack": stack.toString(),
    });
    await app.shutdown().then(
      (_) => print("App has shut down from a server initialization error"),
    );
  }
}
