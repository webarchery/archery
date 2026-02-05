import 'package:archery/archery/archery.dart';
import 'package:archery/src/http/controllers/blog/blog_pages_controller.dart';

import '../../apps/todos.dart';

void webRoutes(Router router) {
  todoRoutes(router);

  router.get('/', (request) async {
    return request.view("welcome");
  });

  router.group(prefix: 'blog',  routes: () {
      router.get('/', BlogPagesController.index);
      router.get('/{slug:string}', BlogPagesController.show);
    },
  );
}
