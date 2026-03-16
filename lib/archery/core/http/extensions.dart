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

/// Type alias for data passed into rendered views.
///
/// View data is a string-keyed map whose values may contain any serializable
/// or template-consumable object.
///
/// Example:
/// ```dart
/// final data = <String, dynamic>{
///   'title': 'Dashboard',
///   'user': currentUser,
/// };
/// ```
typedef ViewData = Map<String, dynamic>;

// calling it thisSession because
// request.session is taken

/// Session helpers attached to [HttpRequest].
///
/// The guest session is identified by the `archery_guest_session` cookie and is
/// loaded from the in-memory session cache when available.
///
/// Example:
/// ```dart
/// final session = request.thisSession;
///
/// if (session != null) {
///   print(session.token);
/// }
/// ```
extension ThisSession on HttpRequest {
  /// Returns the current guest session associated with the request.
  ///
  /// This getter looks for the `archery_guest_session` cookie, resolves the
  /// matching session from the in-memory session registry, updates the
  /// session's `lastActivity` timestamp, and returns it.
  ///
  /// Returns `null` when no matching session can be found or resolution fails.
  ///
  /// Example:
  /// ```dart
  /// final session = request.thisSession;
  ///   if (session != null) {
  ///     print('Guest session active');
  ///   }
  /// ```
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

/// Types of flash data that may be stored on the session.
///
/// Example:
/// ```dart
/// request.flash(key: 'notice', message: 'Saved successfully');
/// request.flash(
///   key: 'email',
///   message: 'The email field is required.',
///   type: FlashMessageType.error,
/// );
/// ```
enum FlashMessageType {
  /// Arbitrary flashed input or temporary request data.
  data,
  /// Flashed validation or request errors.
  error,
  /// General-purpose flashed user-facing messages.
  message }

/// Flash-message helpers attached to [HttpRequest].
///
/// Flash data is stored on the session and intended to survive a short number
/// of request cycles, typically to support redirects followed by view renders.
///
/// Example:
/// ```dart
/// request.flash(
///   key: 'success',
///   message: 'Profile updated successfully.',
/// );
/// ```
extension FlashingMessages on HttpRequest {
  /// Stores a flash message or temporary session value for the next request
  /// cycle.
  ///
  /// This method also initializes the internal `_flashTrips` counter used by
  /// the framework to determine when flashed data should be removed.
  ///
  /// By default, the value is stored in `flashMessages`, but it can also be
  /// written to `data` or `errors` depending on [type].
  ///
  /// Parameters:
  /// - `key`: The session key to store.
  /// - `message`: The flashed value.
  /// - `type`: The flash storage target. Defaults to
  ///   [FlashMessageType.message].
  ///
  /// Example:
  /// ```dart
  /// request.flash(
  ///   key: 'status',
  ///   message: 'Welcome back!',
  /// );
  ///
  /// request.flash(
  ///   key: 'email',
  ///   message: 'The email has already been taken.',
  ///   type: FlashMessageType.error,
  /// );
  /// ```
  void flash({required String key, required String message, FlashMessageType type = .message}) {


    final flashTrip = App().container.tryMake<int>(name: '_flashTrips');

    if(flashTrip == null) {
      App().container.bindInstance<int>(name: "_flashTrips", 1);

      switch(type) {
        case .data:
          thisSession?.data.addAll({key: message});
        case .error:
          thisSession?.errors.addAll({key: message});
        case .message:
          thisSession?.flashMessages.addAll({key: message});
      }
    }
  }
}

/// Extension on [HttpRequest] to render HTML views.
///
/// This extension centralizes template rendering, CSRF token setup, response
/// header configuration, and request/session view data composition.
///
/// Example:
/// ```dart
/// return request.view('dashboard.index', {
///   'title': 'Dashboard',
///   'posts': posts,
/// });
/// ```
extension View on HttpRequest {
  /// Static response headers applied to rendered HTML views.
  ///
  /// These headers enable caching and apply a default browser-security policy
  /// for HTML responses.
  static const _viewHeaders = {
    HttpHeaders.varyHeader: 'Accept-Encoding',
    HttpHeaders.cacheControlHeader: 'public, max-age=3600',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'SAMEORIGIN',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'X-XSS-Protection': '1; mode=block',
    HttpHeaders.connectionHeader: 'keep-alive',
    'Content-Type': 'text/html; charset=utf-8',
  };

  /// Renders an HTML template and writes it to the response.
  ///
  /// This method:
  /// - resolves the configured [TemplateEngine]
  /// - loads the authenticated user into session state
  /// - reuses or generates a CSRF token
  /// - merges provided [data] with session and CSRF values
  /// - renders the template into HTML
  /// - configures response headers and content length
  /// - stores a CSRF cookie when a new token is generated
  ///
  /// Parameters:
  /// - `template`: The template identifier to render.
  /// - `data`: Optional view data passed into the template.
  ///
  /// Returns the active [HttpResponse] after writing and closing it.
  ///
  /// Example:
  /// ```dart
  /// return request.view('users.show', {
  ///   'user': user,
  ///   'pageTitle': 'User Profile',
  /// });
  /// ```
  Future<HttpResponse> view(String template, [ViewData? data]) async {
    final container = App().container; // Cache reference
    final engine = container.make<TemplateEngine>();

    // 1. Parallelize data fetching if possible, but definitely cache user
    thisSession?.user = await Auth.user(this);

    // 2. Optimized Cookie Access: Search cookies ONCE
    Cookie? csrfCookie;
    Cookie? guestCookie;
    for (var c in cookies) {
      if (c.name == 'archery_csrf_token') csrfCookie = c;
      if (c.name == 'archery_guest_session') guestCookie = c;
      if (csrfCookie != null && guestCookie != null) break;
    }

    String token;
    bool isNewToken = false;

    if (data?.containsKey('csrf_token') ?? false) {
      token = data!['csrf_token'];
    } else if (csrfCookie != null) {
      token = csrfCookie.value;
    } else {
      token = App.generateKey();
      isNewToken = true;
    }

    try {
      // 3. Merging data: Use a single map spread
      final viewData = {
        ...?data,
        "session": thisSession?.toJson(),
        'csrf_token': token
      };

      final html = await engine.render(template, viewData);
      final bodyBytes = utf8.encode(html);

      // 4. Batch Header Setting
      response.headers.contentLength = bodyBytes.length;
      _viewHeaders.forEach(response.headers.set);
      response.persistentConnection = true;

      if (isNewToken) {
        response.cookies.add(
            Cookie('archery_csrf_token', token)
              ..httpOnly = true ..secure = true
              ..sameSite = SameSite.lax ..path = '/'
        );
      }

      // 5. Direct lookup for sessions list
      final sessions = App().tryMake<List<Session>>();
      if (sessions != null && guestCookie != null) {
        final session = sessions.firstWhereOrNull((s) => s.token == guestCookie!.value);
        if (session != null) session.csrf = token;
      }

      return response
        ..add(bodyBytes) // Use .add() for bytes to bypass re-encoding strings
        ..close();

    } catch (e) {
      return response
        ..write("error") // Use .add() for bytes to bypass re-encoding strings
        ..close();
    }
  }
}

/// Extension on [HttpRequest] to send JSON responses.
///
/// Example:
/// ```dart
/// return request.json({
///   'ok': true,
///   'data': items,
/// });
/// ```
extension Json on HttpRequest {

  /// Cached JSON content type used for response generation.
  static final _jsonType = ContentType.json;

  /// Writes a JSON response and closes the connection.
  ///
  /// If [data] is already a string, it is written as-is. Otherwise the value is
  /// encoded with `jsonEncode`.
  ///
  /// The response is sent with `200 OK`, a JSON content type, content length,
  /// cache headers, and persistent connection enabled.
  ///
  /// Example:
  /// ```dart
  /// return request.json({
  ///   'message': 'User created',
  ///   'user': user.toJson(),
  /// });
  /// ```
  Future<HttpResponse> json([dynamic data]) async {
    final String body = (data is String) ? data : jsonEncode(data);
    response.headers.contentType = _jsonType;

    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=300');
    response.headers.contentLength = utf8.encode(body).length;
    response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    response.persistentConnection = true;

    return response
      ..statusCode = HttpStatus.ok
      ..write(body)
      ..close();
  }
}
/// Static security headers shared by cached or text-based responses.
///
/// Example:
/// ```dart
/// response.headers.set(
///   'X-Content-Type-Options',
///   staticSecurityHeaders['X-Content-Type-Options'],
/// );
/// ```
const Map<String, String> staticSecurityHeaders = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'SAMEORIGIN',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'X-XSS-Protection': '1; mode=block',
  'Vary': 'Accept-Encoding',
  'Cache-Control': 'public, max-age=300, must-revalidate',
};

/// Extension on [HttpRequest] to send plain-text responses.
///
/// Example:
/// ```dart
/// return request.text('Server is healthy');
/// ```
extension Text on HttpRequest {
  Future<HttpResponse> text([dynamic data]) async {
    // Only the essentials
    response.headers.contentType = ContentType.text;
    response.headers.contentLength = utf8.encode(data).length;
    response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

    response.persistentConnection = true;
    // Optional: Cache-control is good for performance
    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=300');

    return response
      ..statusCode = HttpStatus.ok
      ..write(data)
      ..close();
  }
}

/// Extension on [HttpRequest] to send a 404 response.
///
/// The framework first attempts to render the `errors.404` template. If the
/// template is unavailable or rendering fails, it falls back to a plain-text
/// `404 Not Found` response.
///
/// Example:
/// ```dart
/// return request.notFound();
/// ```
extension NotFound on HttpRequest {
  /// Renders `errors.404` or falls back to a plain 404 response.
  ///
  /// A CSRF cookie is also attached to the response, reusing the current token
  /// when available or generating a new one otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (post == null) {
  ///   return request.notFound();
  /// }
  /// ```
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
///
/// Example:
/// ```dart
/// return request.unAuthenticated();
/// ```
extension UnAuthenticated on HttpRequest {
  /// Renders `errors.401` or falls back to a plain 401 response.
  ///
  /// A CSRF cookie is also attached to the response, reusing the current token
  /// when available or generating a new one otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (await request.user == null) {
  ///   return request.unAuthenticated();
  /// }
  /// ```
  Future<HttpResponse> unAuthenticated() async {
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

/// Sends a 403 forbidden response.
///
/// Attempts to render `errors.403`. If the template is missing, falls back to
/// a plain-text response.
///
/// Example:
/// ```dart
/// return request.forbidden();
/// ```
extension UnAuthorized on HttpRequest {
  /// Renders `errors.403` or falls back to a plain 403 response.
  ///
  /// A CSRF cookie is also attached to the response, reusing the current token
  /// when available or generating a new one otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (!user.can('delete-post')) {
  ///   return request.forbidden();
  /// }
  /// ```
  Future<HttpResponse> forbidden() async {
    final engine = App().container.make<TemplateEngine>();

    try {
      final html = await engine.render("errors.403", {});
      response.headers.contentType = ContentType.html;
      final csrfCookie = cookies.firstWhereOrNull((c) => c.name == 'archery_csrf_token');
      final cookie = Cookie('archery_csrf_token', csrfCookie?.value ?? App.generateKey())
        ..httpOnly = true
        ..secure = true
        ..sameSite = SameSite.lax
        ..path = '/';

      return response
        ..statusCode = HttpStatus.forbidden
        ..cookies.add(cookie)
        ..write(html)
        ..close();
    } catch (e) {
      return response
        ..statusCode = HttpStatus.forbidden
        ..write("403 Forbidden")
        ..close();
    }
  }
}

/// Redirect helpers attached to [HttpRequest].
///
/// These methods are convenience wrappers around `HttpResponse.redirect` and
/// encode common framework redirect targets.
///
/// Example:
/// ```dart
/// request.redirectToLogin();
/// ```
extension Redirect on HttpRequest {
  /// Redirects the client back to the referring URL.
  ///
  /// If the `Referer` header is missing or invalid, the request is redirected
  /// to the home page instead.
  ///
  /// Example:
  /// ```dart
  /// request.redirectBack();
  /// ```
  void redirectBack() {
    try {
      final referer = headers.value(HttpHeaders.refererHeader);
      response.redirect(Uri.parse(referer!));
    } catch (e) {
      redirectHome();
    }
  }

  /// Redirects the client to `/`.
  ///
  /// Example:
  /// ```dart
  /// request.redirectHome();
  /// ```
  void redirectHome() {
    response.redirect(Uri.parse('/'));
  }

  /// Redirects the client to `/user/dashboard`.
  ///
  /// Example:
  /// ```dart
  /// request.redirectToDashboard();
  /// ```
  void redirectToDashboard() {
    response.redirect(Uri.parse('/user/dashboard'));
  }

  /// Redirects the client to `/login`.
  ///
  /// Example:
  /// ```dart
  /// request.redirectToLogin();
  /// ```
  void redirectToLogin() {
    response.redirect(Uri.parse('/login'));
  }

  /// Redirects the client to the provided [path].
  ///
  /// If the path cannot be parsed, the request falls back to a home-page
  /// redirect.
  ///
  /// Example:
  /// ```dart
  /// request.redirectTo(path: '/posts');
  /// ```
  void redirectTo({String path = "/"}) {
    try {
      response.redirect(Uri.parse(path));
      response.close();
    } catch (e) {
      redirectHome();
    }
  }
}

/// Per-request cache used for parsed form access.
///
/// The [Expando] ensures each [HttpRequest] stores its own [FormRequest]
/// instance without reparsing the body repeatedly.
///
/// Example:
/// ```dart
/// final form = request.form();
/// ```
final _formRequestCache = Expando<FormRequest>();

/// Cached form parsing for the current [HttpRequest].
///
/// Returns a [FormRequest] wrapper. The instance is cached per request using an
/// [Expando], so repeated calls reuse the same parser state.
///
/// Example:
/// ```dart
/// final form = request.form();
/// final email = await form.input('email');
/// ```
extension HttpRequestFormExtension on HttpRequest {
  /// Returns the cached [FormRequest] wrapper for this request.
  ///
  /// A new wrapper is created only once per request instance.
  ///
  /// Example:
  /// ```dart
  /// final form = request.form();
  /// final values = await form.all();
  /// ```
  FormRequest form() {
    if (_formRequestCache[this] == null) {
      _formRequestCache[this] = FormRequest(this);
    }
    return _formRequestCache[this]!;
  }
}

/// Model retrieval helpers that map to Archery ORM "or fail" methods.
///
/// These helpers forward to `Model.firstOrFail` and `Model.findOrFail`, passing
/// through the current request so the ORM can generate request-aware failure
/// responses.
///
/// Example:
/// ```dart
/// final user = await request.firstOrFail<User>(
///   field: 'email',
///   value: 'jane@example.com',
/// );
/// ```
extension FirstOrFail on HttpRequest {
  /// Retrieves the first model matching the given field/value pair or fails.
  ///
  /// This method forwards to `Model.firstOrFail` and includes the current
  /// request context.
  ///
  /// Parameters:
  /// - `field`: The column or field name to query.
  /// - `value`: The value to compare against.
  /// - `comp`: The comparison operator. Presently forwarded by signature only.
  /// - `disk`: The database disk to query.
  ///
  /// Example:
  /// ```dart
  /// final post = await request.firstOrFail<Post>(
  ///   field: 'slug',
  ///   value: 'welcome-to-archery',
  /// );
  /// ```
  Future<dynamic> firstOrFail<T extends Model>({required String field, required dynamic value, String comp = "==", DatabaseDisk disk = Model.defaultDisk}) async {
    return await Model.firstOrFail<T>(request: this, field: field, value: value, disk: disk);
  }

  /// Retrieves a model by primary identifier or fails.
  ///
  /// This method forwards to `Model.findOrFail` and includes the current
  /// request context.
  ///
  /// Parameters:
  /// - `id`: The model identifier.
  /// - `disk`: The database disk to query.
  ///
  /// Example:
  /// ```dart
  /// final post = await request.findOrFail<Post>(id: 42);
  /// ```
  Future<dynamic> findOrFail<T extends Model>({required dynamic id, DatabaseDisk disk = Model.defaultDisk}) async {
    return await Model.findOrFail<T>(request: this, id: id, disk: disk);
  }
}

/// Convenience authenticated-user lookup attached to [HttpRequest].
///
/// Example:
/// ```dart
/// final currentUser = await request.user;
/// ```
extension RequestUser on HttpRequest {
  /// Returns the currently authenticated [User], if one can be resolved.
  ///
  /// This getter delegates to `Auth.user(this)`.
  ///
  /// Example:
  /// ```dart
  /// final user = await request.user;
  /// if (user != null) {
  ///   print(user.email);
  /// }
  /// ```
  Future<User?> get user async {
    return await Auth.user(this);
  }
}

