import 'package:archery/archery/archery.dart';

base class StartSession {
  static Future<dynamic> middleware(
    HttpRequest request,
    Future<void> Function() next,
  ) async {
    await Session.init(request);
    await next();
  }
}
