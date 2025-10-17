import 'package:archery/archery/archery.dart';
class AppKernel {
  final List<HttpMiddleware> middleware;
  final Router router;

  AppKernel({this.middleware = const [], required this.router});

  void handle(HttpRequest request) {
    _runMiddleware(request, 0);
  }

  void _runMiddleware(HttpRequest request, int index) {
    if (index < middleware.length) {
      middleware[index](request, () => _runMiddleware(request, index + 1));
    } else {
      router.dispatch(request);
    }
  }
}
