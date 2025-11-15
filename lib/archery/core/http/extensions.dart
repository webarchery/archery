import 'package:archery/archery/archery.dart';

/// Type alias for view data.
typedef ViewData = Map<String, dynamic>;

// calling is thisSession because
// request.session is taken
extension ThisSession on HttpRequest {
  Session? get thisSession {
    try {
      final cookie = cookies.firstWhereOrNull(
        (cookie) => cookie.name == "archery_guest_session",
      );
      final sessions = App().tryMake<List<Session>>();
      if (cookie != null) {
        final session = sessions?.firstWhereOrNull(
          (session) => session.token == cookie.value,
        );
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
// extension View on HttpRequest {
//   /// Renders a template and sends HTML response.
//   ///
//   /// - Sets `Content-Type: text/html`
//   /// - Adds caching and security headers
//   /// - Sets XSRF token cookie
//   /// - Handles errors gracefully in debug mode
//   Future<HttpResponse> view(String template, [ViewData? data]) async {
//     final engine = App().container.make<TemplateEngine>();
//     final config = App().container.make<AppConfig>();
//
//     final user = await Auth.user(this);
//     if (user != null) {
//       final userData = {"user": user.toJson()};
//       data = {...?data, ...userData};
//     }
//
//     try {
//       final html = engine.render(template, data ?? {});
//
//       // --- Performance headers ---
//       response.headers.contentType = ContentType.html;
//       response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
//
//       response.headers.set(
//         HttpHeaders.cacheControlHeader,
//         'no-cache, no-store, must-revalidate, max-age=0',
//       );
//       response.headers.set(
//         HttpHeaders.pragmaHeader,
//         'no-cache',
//       ); // HTTP/1.0 compatibility
//       response.headers.set(
//         HttpHeaders.expiresHeader,
//         '0',
//       ); // or a date in the past, e.g., 'Tue, 01 Jan 1980 00:00:00 GMT'
//       //
//       // // --- Security headers ---
//       response.headers.set('X-Content-Type-Options', 'nosniff');
//       response.headers.set('X-Frame-Options', 'SAMEORIGIN');
//       response.headers.set(
//         'Referrer-Policy',
//         'strict-origin-when-cross-origin',
//       );
//       response.headers.set('X-XSS-Protection', '1; mode=block');
//
//       final cookie = Cookie('archery_csrf_token', App.generateKey())
//         ..httpOnly = true
//         ..secure = true
//         ..sameSite = SameSite.lax;
//
//       final sessions = App().tryMake<List<Session>>();
//       if (sessions != null && sessions.isNotEmpty) {
//         final requestCookie = cookies.firstWhereOrNull(
//           (cookie) => cookie.name == "archery_guest_session",
//         );
//
//         if (requestCookie != null) {
//           final session = sessions.firstWhereOrNull(
//             (session) => session.token == requestCookie.value,
//           );
//
//           if (session != null) {
//             session.csrf = cookie.value;
//           }
//         }
//       }
//
//       return response
//         ..cookies.add(cookie)
//         ..write(html)
//         ..close();
//     } catch (e, stack) {
//       if (config.get('app.debug')) {
//         return response
//           ..statusCode = HttpStatus.internalServerError
//           ..write("$e\n\n$stack")
//           ..close();
//       }
//       return response
//         ..statusCode = HttpStatus.internalServerError
//         ..write(e)
//         ..close();
//     }
//   }
// }

/// Extension on [HttpRequest] to send JSON responses.
extension Json on HttpRequest {
  /// Sends JSON response with security headers and XSRF cookie.
  HttpResponse json([dynamic data]) {
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

    final cookie = Cookie('archery_csrf_token', App.generateKey())
      ..httpOnly = true
      ..secure = true
      ..sameSite = SameSite.lax;

    response.headers.contentType = ContentType.json;

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
  HttpResponse text([dynamic data]) {
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

    final cookie = Cookie('archery_csrf_token', App.generateKey())
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

      final cookie = Cookie('archery_csrf_token', App.generateKey())
        ..httpOnly = true
        ..secure = true
        ..sameSite = SameSite.lax;

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
  /// Renders `errors.404` template or plain 404.
  HttpResponse notAuthenticated() {
    final engine = App().container.make<TemplateEngine>();

    try {
      final html = engine.render("errors.401", {});
      response.headers.contentType = ContentType.html;
      final cookie = Cookie('archery_csrf_token', App.generateKey())
        ..httpOnly = true
        ..secure = true
        ..sameSite = SameSite.lax;

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

extension HttpRequestFormExtension on HttpRequest {
  FormRequest form() => FormRequest(this);
}


extension View on HttpRequest {
  Future<HttpResponse> view(String template, [ViewData? data]) async {
    final engine = App().container.make<TemplateEngine>();
    final config = App().container.make<AppConfig>();
    final isProduction = config.get('app.env') == 'production';
    final appUrl = config.get('app.url'); // Add this to your config

    // Get user data for template
    final user = await Auth.user(this);
    if (user != null) {
      final userData = {"user": user.toJson()};
      data = {...?data, ...userData};
    }

    // Add environment and config data to all templates
    final templateData = {
      ...?data,
      'isProduction': isProduction,
      'appUrl': appUrl,
      'appName': config.get('app.name'),
      'csrfToken': await _getOrCreateCsrfToken(this),
    };

    try {
      final html = engine.render(template, templateData);

      // --- Headers ---
      response.headers.contentType = ContentType.html;
      response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');

      // Cache headers - different for production
      if (isProduction) {
        response.headers.set(
          HttpHeaders.cacheControlHeader,
          'public, max-age=300', // 5 minutes for production
        );
      } else {
        response.headers.set(
          HttpHeaders.cacheControlHeader,
          'no-cache, no-store, must-revalidate, max-age=0',
        );
      }

      response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      response.headers.set(HttpHeaders.expiresHeader, '0');

      // --- Security headers ---
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('X-Frame-Options', 'SAMEORIGIN');
      response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
      response.headers.set('X-XSS-Protection', '1; mode=block');

      // Add CSP header in production
      // if (isProduction) {
      //   response.headers.set(
      //       'Content-Security-Policy',
      //       "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';"
      //   );
      // }

      // --- CSRF Cookie ---
      final csrfToken = await _getOrCreateCsrfToken(this);
      final cookie = Cookie('archery_csrf_token', csrfToken)
        ..httpOnly = true
        ..secure = isProduction
        ..sameSite = isProduction ? SameSite.none : SameSite.lax
        ..path = '/'
        ..maxAge = 3600; // 1 hour

      // Set domain in production for cross-subdomain cookies
      if (isProduction) {
        cookie.domain = '.dartmastery.com'; // Replace with your actual domain
      }


      return response
        ..cookies.add(cookie)
        ..write(html)
        ..close();
    } catch (e, stack) {
      if (config.get('app.debug')) {
        return response
          ..statusCode = HttpStatus.internalServerError
          ..write("Error rendering template: $e\n\n$stack")
          ..close();
      }
      // In production, render a friendly error page
      return response
        ..statusCode = HttpStatus.internalServerError
        ..write(engine.render('error', {'message': 'Something went wrong'}))
        ..close();
    }
  }

  Future<String> _getOrCreateCsrfToken(HttpRequest request) async {
    final sessions = App().tryMake<List<Session>>();
    if (sessions != null && sessions.isNotEmpty) {
      final requestCookie = request.cookies.firstWhereOrNull(
            (cookie) => cookie.name == "archery_guest_session",
      );

      if (requestCookie != null) {
        final session = sessions.firstWhereOrNull(
              (session) => session.token == requestCookie.value,
        );

        if (session != null && session.csrf != null) {
          return session.csrf!;
        }
      }
    }

    // Generate new token if none exists
    return App.generateKey();
  }
}