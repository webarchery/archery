import 'package:archery/archery/archery.dart';

/// Type alias for view data.
typedef ViewData = Map<String, dynamic>;

// calling it thisSession because
// request.session is taken
extension ThisSession on HttpRequest {
  Session? get thisSession {
    try {
      final cookie = cookies.firstWhereOrNull((cookie) => cookie.name == "archery_guest_session");
      final sessions = App().tryMake<List<Session>>();
      if (cookie != null) {
        final session = sessions?.firstWhereOrNull((session) => session.token == cookie.value);
        if (session != null) {
          session.lastActivity = DateTime.now();
          return session;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Extension on [HttpRequest] to render HTML views.
extension View on HttpRequest {
  /// Renders a template and sends HTML response.
  ///
  /// - Sets `Content-Type: text/html`
  /// - Adds caching and security headers
  /// - Sets XSRF token cookie
  /// - Handles errors gracefully in debug mode
  Future<HttpResponse> view(String template, [ViewData? data]) async {
    final engine = App().container.make<TemplateEngine>();
    final config = App().container.make<AppConfig>();

    final user = await Auth.user(this);
    if (user != null) {
      final userData = {"user": user.toJson()};
      data = {...?data, ...userData};
    }

    // Ensure CSRF token is available to the view
    if (data != null && !data.containsKey('csrf_token') || data == null) {
      final csrfCookie = cookies.firstWhereOrNull((cookie) => cookie.name == 'archery_csrf_token');
      // If cookie exists, use it. If not, generate new one (which will be set in response below)
      final token = csrfCookie?.value ?? App.generateKey();
      data = {...?data, 'csrf_token': token};
    }

    try {
      final html = await engine.render(template, data);

      // --- Performance headers ---
      response.headers.contentType = ContentType.html;
      response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');

      response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate, max-age=0');
      response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      response.headers.set(HttpHeaders.expiresHeader, '0');

      // --- Security headers ---
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('X-Frame-Options', 'SAMEORIGIN');
      response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
      response.headers.set('X-XSS-Protection', '1; mode=block');

      final cookie = Cookie('archery_csrf_token', data['csrf_token'] ?? App.generateKey())
        ..httpOnly = true
        ..secure = true
        ..sameSite = SameSite.lax
        ..path = '/';

      final sessions = App().tryMake<List<Session>>();
      if (sessions != null && sessions.isNotEmpty) {
        final requestCookie = cookies.firstWhereOrNull((cookie) => cookie.name == "archery_guest_session");

        if (requestCookie != null) {
          final session = sessions.firstWhereOrNull((session) => session.token == requestCookie.value);

          if (session != null) {
            session.csrf = cookie.value;
          }
        }
      }

      return response
        ..cookies.add(cookie)
        ..write(html)
        ..close();
    } catch (e, stack) {
      if (config.get('app.debug')) {
        return response
          ..statusCode = HttpStatus.internalServerError
          ..write("$e\n\n$stack")
          ..close();
      }
      return response
        ..statusCode = HttpStatus.internalServerError
        ..write(e)
        ..close();
    }
  }
}

/// Extension on [HttpRequest] to send JSON responses.
extension Json on HttpRequest {
  /// Sends JSON response with security headers and XSRF cookie.
  Future<HttpResponse> json([dynamic data]) async {

    // --- Performance headers ---
    response.headers.contentType = ContentType.json;
    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=300, must-revalidate');
    response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');

    // --- Security headers ---
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'SAMEORIGIN');
    response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    response.headers.set('X-XSS-Protection', '1; mode=block');

    final csrfCookie = cookies.firstWhereOrNull((c) => c.name == 'archery_csrf_token');
    final cookie = Cookie('archery_csrf_token', csrfCookie?.value ?? App.generateKey())
      ..httpOnly = true
      ..secure = true
      ..sameSite = SameSite.lax
      ..path = '/';

    return response
      ..statusCode = HttpStatus.ok
      ..cookies.add(cookie)
      ..write(jsonEncode(data))
      ..close();
  }
}

/// Extension on [HttpRequest] to send plain text.
extension Text on HttpRequest {
  /// Sends plain text response.
  Future<HttpResponse> text([dynamic data]) async {

    response.headers.contentType = ContentType.text;
    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=300, must-revalidate');
    response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');

    // --- Security headers ---
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'SAMEORIGIN');
    response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    response.headers.set('X-XSS-Protection', '1; mode=block');

    final csrfCookie = cookies.firstWhereOrNull((c) => c.name == 'archery_csrf_token');
    final cookie = Cookie('archery_csrf_token', csrfCookie?.value ?? App.generateKey())
      ..httpOnly = true
      ..secure = true
      ..sameSite = SameSite.lax
      ..path = '/';

    return response
      ..statusCode = HttpStatus.ok
      ..cookies.add(cookie)
      ..write(data)
      ..close();
  }
}

/// Extension on [HttpRequest] to send 404 with fallback template.
extension NotFound on HttpRequest {
  /// Renders `errors.404` template or plain 404.
  Future<HttpResponse> notFound() async {
    final engine = App().container.make<TemplateEngine>();

    try {
      final html = await engine.render("errors.404", {});
      response.headers.contentType = ContentType.html;

      final csrfCookie = cookies.firstWhereOrNull((c) => c.name == 'archery_csrf_token');
      final cookie = Cookie('archery_csrf_token', csrfCookie?.value ?? App.generateKey())
        ..httpOnly = true
        ..secure = true
        ..sameSite = SameSite.lax
        ..path = '/';

      return response
        ..statusCode = HttpStatus.notFound
        ..cookies.add(cookie)
        ..write(html)
        ..close();
    } catch (e) {
      return response
        ..statusCode = HttpStatus.notFound
        ..write("404 Not Found")
        ..close();
    }
  }
}

extension NotAuthenticated on HttpRequest {
  /// Renders `errors.401` template or plain 401.
  Future<HttpResponse> notAuthenticated() async {
    final engine = App().container.make<TemplateEngine>();

    try {
      final html = await engine.render("errors.401", {});
      response.headers.contentType = ContentType.html;
      final csrfCookie = cookies.firstWhereOrNull((c) => c.name == 'archery_csrf_token');
      final cookie = Cookie('archery_csrf_token', csrfCookie?.value ?? App.generateKey())
        ..httpOnly = true
        ..secure = true
        ..sameSite = SameSite.lax
        ..path = '/';

      return response
        ..statusCode = HttpStatus.unauthorized
        ..cookies.add(cookie)
        ..write(html)
        ..close();
    } catch (e) {
      return response
        ..statusCode = HttpStatus.unauthorized
        ..write("401 Unauthenticated")
        ..close();
    }
  }
}

extension Redirect on HttpRequest {
  void redirectBack() {
    try {
      final referer = headers.value(HttpHeaders.refererHeader);
      response.redirect(Uri.parse(referer!));
    } catch (e) {
      redirectHome();
    }
  }

  void redirectHome() {
    response.redirect(Uri.parse('/'));
  }

  void redirectToDashboard() {
    response.redirect(Uri.parse('/user/dashboard'));
  }

  void redirectToLogin() {
    response.redirect(Uri.parse('/login'));
  }

  void redirectTo({String path = "/"}) {
    try {
      response.redirect(Uri.parse(path));
      response.close();
    } catch (e) {
      redirectHome();
    }
  }
}

final _formRequestCache = Expando<FormRequest>();

extension HttpRequestFormExtension on HttpRequest {
  FormRequest form() {
    if (_formRequestCache[this] == null) {
      _formRequestCache[this] = FormRequest(this);
    }
    return _formRequestCache[this]!;
  }
}
