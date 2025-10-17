import 'package:archery/archery/archery.dart';
import 'package:archery/src/http/routes/api.dart';
import 'package:archery/src/http/routes/web.dart';

Future<void> main(List<String> args) async {

  final app = App();
  app.setKeys();

  final config = await AppConfig.create();
  app.bind<AppConfig>(config);

  await app.boot();

  final router = app.make<Router>();
  webRoutes(router);
  apiRoutes(router);

  final kernel = AppKernel(router: router);

  final port = config.get('server.port') ?? 8080;
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


