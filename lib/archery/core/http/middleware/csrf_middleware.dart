import 'package:archery/archery/archery.dart';

class VerifyCsrfToken {
  static Future<dynamic> middleware(HttpRequest request, void Function() next) async {

    if (_isReading(request)) {
      return next();
    }

    final token = await _getToken(request);

    final sessionToken = await _getSessionToken(request);

    if (token == null || sessionToken == null || token != sessionToken) {
      // Todo - Leaving this snippet for testing
      // print('--- CSRF DEBUG ---');
      // print('Method: ${request.method} ${request.uri}');
      // print('Input Token (Body): $token');
      // print('Session Token (Cookie): $sessionToken');
      // print('All Cookies: ${request.cookies.map((c) => '${c.name}=${c.value}').join(', ')}');
      // print('Headers: ${request.headers.value('content-type')}');
      // print('------------------');

      return request.response
        ..statusCode = HttpStatus.forbidden
        ..write("403 Forbidden: Invalid CSRF Token")
        ..close();
    }

    return next();
  }

  static bool _isReading(HttpRequest request) {
    return ['GET', 'HEAD', 'OPTIONS'].contains(request.method);
  }

  static Future<String?> _getToken(HttpRequest request) async {

    // Check header
    // Todo -current unused, future proofing for jax calls
    final headerToken = request.headers.value('X-CSRF-TOKEN');
    if (headerToken != null) return headerToken;

    // Check input
    try {
      final form = request.form();
      final inputToken = await form.input('_token');

      if (inputToken != null) return inputToken.toString();
    } catch (e) {
      // print('CSRF Body Parse Error: $e');
      // print(s);
    }

    return null;
  }

  static Future<String?> _getSessionToken(HttpRequest request) async {
    final cookie = request.cookies.firstWhereOrNull((c) => c.name == 'archery_csrf_token');
    return cookie?.value;
  }
}
