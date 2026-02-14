import 'package:archery/archery/archery.dart';
import 'package:archery/archery/core/http/middleware/cors_middleware.dart';


Future<void> main(List<String> args) async {

  // init application
  final app = App();
  app.setKeys();

  // parse config folder and attach to container
  final config = await AppConfig.create();
  app.container.singleton<AppConfig>(factory: (_, [_]) => config, eager: true);


  await app.boot().then((_) async {


  });



  // HTTP Server
  // ----------------

  // routes
  final router = app.make<Router>();

  router.get('/', (request) async {
    return request.text("Hello world!");
  });
  // pass router to kernel
  final kernel = AppKernel(
    router: router,
    middleware: [
      VerifyCsrfToken.middleware,
      CorsMiddleware.middleware
    ],
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
    App().archeryLogger.error("Error booting server", {"error": e.toString(), "stack": stack.toString()});
    await app.shutdown().then(
          (_) => print("App has shut down from a server initialization error"),
    );
  }
}


