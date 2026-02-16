// SPDX-FileCopyrightText: 2025 Kwame, III <webarcherydev@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// https://webarchery.dev

import 'package:archery/archery/archery.dart';

/// Type alias for view data.
typedef ViewData = Map<String, dynamic>;

// calling it thisSession because
// request.session is taken
/// Session helpers attached to [HttpRequest].
///
/// The guest session is identified by the `archery_guest_session` cookie and is
/// loaded from the in-memory session cache when available.
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
  static const _viewHeaders = {
    HttpHeaders.varyHeader: 'Accept-Encoding',
    HttpHeaders.cacheControlHeader: 'no-cache, no-store, must-revalidate, max-age=0',
    HttpHeaders.pragmaHeader: 'no-cache',
    HttpHeaders.expiresHeader: '0',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'SAMEORIGIN',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'X-XSS-Protection': '1; mode=block',
  };

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
    String token;
    bool isNewToken = false;

    if (data != null && data.containsKey('csrf_token')) {
      token = data['csrf_token'];
    } else {
      final csrfCookie = cookies.firstWhereOrNull((cookie) => cookie.name == 'archery_csrf_token');
      if (csrfCookie != null) {
        token = csrfCookie.value;
      } else {
        token = App.generateKey();
        isNewToken = true;
      }
      data = {...?data, 'csrf_token': token};
    }

    try {
      final html = await engine.render(template, data);

      // --- Performance & Security headers ---
      response.headers.contentType = ContentType.html;
      _viewHeaders.forEach((key, value) {
        response.headers.set(key, value);
      });

      if (isNewToken) {
        final cookie = Cookie('archery_csrf_token', token)
          ..httpOnly = true
          ..secure = true
          ..sameSite = SameSite.lax
          ..path = '/';
        response.cookies.add(cookie);
      }

      final sessions = App().tryMake<List<Session>>();
      if (sessions != null && sessions.isNotEmpty) {
        final requestCookie = cookies.firstWhereOrNull((cookie) => cookie.name == "archery_guest_session");

        if (requestCookie != null) {
          final session = sessions.firstWhereOrNull((session) => session.token == requestCookie.value);

          if (session != null) {
            session.csrf = token;
          }
        }
      }

      return response
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
  static const _defaultHeaders = {
    HttpHeaders.cacheControlHeader: 'public, max-age=300, must-revalidate',
    HttpHeaders.varyHeader: 'Accept-Encoding',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'SAMEORIGIN',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'X-XSS-Protection': '1; mode=block',
  };

  /// Sends JSON response with security headers.
  Future<HttpResponse> json([dynamic data]) async {
    response.headers.contentType = ContentType.json;
    _defaultHeaders.forEach((key, value) {
      response.headers.set(key, value);
    });

    return response
      ..statusCode = HttpStatus.ok
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


/// Sends a 401 unauthenticated response.
///
/// Attempts to render `errors.401`. If the template is missing, falls back to
/// a plain-text response.
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

/// Redirect helpers attached to [HttpRequest].
///
/// These are convenience wrappers around `HttpResponse.redirect`.
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


/// Cached form parsing for the current [HttpRequest].
///
/// Returns a [FormRequest] wrapper. The instance is cached per-request using an
/// [Expando] so repeated calls do not re-parse the request body
extension HttpRequestFormExtension on HttpRequest {
  FormRequest form() {
    if (_formRequestCache[this] == null) {
      _formRequestCache[this] = FormRequest(this);
    }
    return _formRequestCache[this]!;
  }
}


/// Model retrieval helpers that map to Archery ORM "or fail" methods.
///
/// These helpers forward to `Model.firstOrFail` / `Model.findOrFail` and pass
/// through the current request (so the ORM can generate appropriate failure
/// responses).
extension FirstOrFail on HttpRequest {
  Future<dynamic> firstOrFail<T extends Model>({required String field, required dynamic value, String comp = "==", DatabaseDisk disk = Model.defaultDisk}) async {
    return await Model.firstOrFail<T>(request: this, field: field, value: value, disk: disk);
  }

  Future<dynamic> findOrFail<T extends Model>({required dynamic id, DatabaseDisk disk = Model.defaultDisk}) async {
    return await Model.findOrFail<T>(request: this, id: id, disk: disk);
  }
}