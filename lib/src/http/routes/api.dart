import 'package:archery/archery/archery.dart';

final config = App().make<AppConfig>();

void apiRoutes(Router router) {

  router.group(prefix: '/api', middleware: [], routes: () {

      router.get('/user', (request) async {

        return request.json({
          "username": "jason",
          "email": "jason@example.com",
          "password": "password",
          "created_at": DateTime.now().toIso8601String(),
        });

      });
    },
  );
}
