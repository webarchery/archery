import 'package:archery/archery/archery.dart';


void webRoutes(Router router) {
  router.get('/', (request) async {
    return request.view("welcome");
  });
}
