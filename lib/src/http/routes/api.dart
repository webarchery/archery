import 'package:archery/archery/archery.dart';

/// Example API routes.
///
/// This is a scaffold route registrar intended for starter projects. It defines
/// a small `/api` group and a sample endpoint.
void apiRoutes(Router router) {

  router.group(prefix: '/api', middleware: [], routes: () {

      router.get('/user', middleware: [Auth.middleware], (request) async {
        return request.json(await request.user);
      });

      router.get('/text', (request) async {
        return request.text("hello world");
      });

      router.get('/json', (request) async {
        return request.json({"name": "Archery Web Framework", "version": "1.5.0"});
      });
    },
  );
}
