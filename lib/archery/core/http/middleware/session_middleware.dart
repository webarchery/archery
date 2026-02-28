import 'package:archery/archery/archery.dart';

base class StartSession {
  static Future<dynamic> middleware(
    HttpRequest request,
    Future<void> Function() next,
  ) async {
    final session = await Session.init(request);
    // print(session?.toMetaJson());
    await next();
  }
}
