import 'package:archery/archery/archery.dart';

void apiRoutes(Router router) {
  router.group(
    prefix: '/api',
    middleware: [],
    routes: () {
      router.get('/user', (request) async {
        return request.json({
          "username": "archer",
          "email": "archer@webarchery.dev",
          "password": "password",
          "created_at": DateTime.now().toIso8601String(),
        });
      });
    },
  );
}
