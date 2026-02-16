import 'package:archery/archery/archery.dart';

/// Example web routes.
///
/// This is a scaffold route registrar intended for starter projects. It defines
/// a minimal home route that renders the `welcome` view.
void webRoutes(Router router) {
  router.group(
    middleware: [StartSession.middleware, VerifyCsrfToken.middleware],
    routes: () {
      router.get('/', (request) async {
        return request.view("welcome");
      });
    },
  );
}
