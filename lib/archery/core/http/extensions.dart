import 'package:archery/archery/archery.dart';

/// Type alias for view data.
typedef ViewData = Map<String, dynamic>;

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

    try {
      final html = engine.render(template, data ?? {});

      // --- Performance headers ---
      response.headers.contentType = ContentType.html;
      response.headers.set(
        HttpHeaders.cacheControlHeader,
        'public, max-age=300, must-revalidate',
      );
      response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
      //
      // // --- Security headers ---
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('X-Frame-Options', 'SAMEORIGIN');
      response.headers.set(
        'Referrer-Policy',
        'strict-origin-when-cross-origin',
      );
      response.headers.set('X-XSS-Protection', '1; mode=block');

      final cookie =
          Cookie(
              'xsrf-token-${config.get('app.timestamp').toString().replaceAll(':', '-')}',
              "${config.get('app.id')}",
            )
            ..httpOnly = true
            ..secure =
                true // only over HTTPS
            ..sameSite = SameSite.lax;

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
  HttpResponse json([dynamic data]) {
    final config = App().container.make<AppConfig>();

    // --- Performance headers ---
    response.headers.contentType = ContentType.html;
    response.headers.set(
      HttpHeaders.cacheControlHeader,
      'public, max-age=300, must-revalidate',
    );
    response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
    //
    // // --- Security headers ---
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'SAMEORIGIN');
    response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    response.headers.set('X-XSS-Protection', '1; mode=block');

    final cookie =
        Cookie(
            'xsrf-json-token-${config.get('app.timestamp').toString().replaceAll(':', '-')}',
            "${config.get('app.id')}",
          )
          ..httpOnly = true
          ..secure = true
          ..sameSite = SameSite.lax;

    response.headers.contentType = ContentType.json;

    return response
      ..cookies.add(cookie)
      ..write(jsonEncode(data))
      ..close();
  }
}

/// Extension on [HttpRequest] to send plain text.
extension Text on HttpRequest {
  /// Sends plain text response.
  HttpResponse text([dynamic data]) {
    final config = App().container.make<AppConfig>();
    response.headers.contentType = ContentType.html;
    response.headers.set(
      HttpHeaders.cacheControlHeader,
      'public, max-age=300, must-revalidate',
    );
    response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');

    // --- Security headers ---
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'SAMEORIGIN');
    response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    response.headers.set('X-XSS-Protection', '1; mode=block');

    final cookie =
        Cookie(
            'xsrf-text-token-${config.get('app.timestamp').toString().replaceAll(':', '-')}',
            "${config.get('app.id')}",
          )
          ..httpOnly = true
          ..secure = true
          ..sameSite = SameSite.lax;

    response.headers.contentType = ContentType.text;
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
  HttpResponse notFound() {
    final engine = App().container.make<TemplateEngine>();

    try {
      final html = engine.render("errors.404", {});
      response.headers.contentType = ContentType.html;
      return response
        ..statusCode = HttpStatus.notFound
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

extension RedirectHome on HttpRequest {
  /// Renders `errors.404` template or plain 404.
  void redirectHome() {
    response.redirect(Uri.parse("/"));
    response.close();
  }
}

extension RedirectTo on HttpRequest {
  /// Renders `errors.404` template or plain 404.
  void redirectTo({String path = "/"}) {
    try {
      response.redirect(Uri.parse(path));
      response.close();
    } catch (e) {
      redirectHome();
    }
  }
}

extension RedirectBack on HttpRequest {
  /// Renders `errors.404` template or plain 404.
  void redirectBack() {
    try {
      final referer = headers.value(HttpHeaders.refererHeader);

      response.redirect(Uri.parse(referer!));
      response.close();
    } catch (e) {
      redirectHome();
    }
  }
}
