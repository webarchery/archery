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

/// Guest session record used for unauthenticated visitors.
///
/// Archery uses this model to track a visitor session token (stored in the
/// `archery_guest_session` cookie) and last activity timestamp. This guest
/// session is also used as the binding point for CSRF token association.
/// Sessions are looked up in the application container before the database and
/// expire after one hour of inactivity.
class Session extends Model with InstanceDatabaseOps<Session> {
  late String token;
  late DateTime lastActivity = DateTime.now();

  Map<String, dynamic> data = {};
  Map<String, dynamic> errors = {};
  Map<String, dynamic> flashMessages = {};

  User? user;
  String? csrf;

  Session({required this.token}) : super.fromJson({});

  static List<Session>? get _containerSessions {
    return App().tryMake<List<Session>>();
  }

  /// Restores or creates a guest session, refreshing activity on each reuse.
  ///
  /// Requests under `/api/` do not receive a guest session. Expired records are
  /// deleted and replaced with a new session and cookie.
  static Future<Session?> init(HttpRequest request) async {
    // API routes bypass browser guest-session initialization.
    if (request.uri.path.startsWith('/api/')) {
      return null;
    }

    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_guest_session");

    // A first-time visitor has no session token to restore.
    if (cookie == null) {
      return await _createNewSession(request);
    }

    // Prefer the shared in-memory instance when it is available.
    final containerSession = _checkContainer(cookie.value);

    if (containerSession != null) {
      if (_validateSession(containerSession)) {
        containerSession.lastActivity = DateTime.now();
        await containerSession.save();
        return containerSession;
      }

      await containerSession.delete();
      _containerSessions?.remove(containerSession);
      return await _createNewSession(request);
    }

    // Restore persisted sessions that are absent from the container cache.

    final dbSession = await _checkDB(cookie.value);

    if (dbSession != null) {
      if (_validateSession(dbSession)) {
        dbSession.lastActivity = DateTime.now();
        _containerSessions?.add(dbSession);
        await dbSession.save();
        return dbSession;
      }

      await dbSession.delete();
      return await _createNewSession(request);
    }

    // An unknown cookie token is replaced rather than reused.

    return await _createNewSession(request);
  }

  /// Restores the token and activity timestamp from a stored record.
  ///
  /// Missing or malformed activity timestamps retain the current-time default.
  Session.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    if (json['token'] != null && json['token'] is String) {
      token = json['token'];
    }

    if (json['last_activity'] != null && json['last_activity'] is String) {
      try {
        lastActivity = DateTime.parse(json['last_activity'] as String);
      } catch (e) {
        lastActivity = DateTime.now();
      }
    }
  }

  /// Defines the database columns required for persisting sessions.
  ///
  /// Both `email` and `token` are required text fields.
  ///
  /// Example:
  /// ```dart
  /// final columns = AuthSession.columnDefinitions;
  /// print(columns['last_activity']); // TEXT NOT NULL
  /// print(columns['token']); // TEXT NOT NULL
  /// ```
  static Map<String, String> columnDefinitions = {'token': 'TEXT NOT NULL', 'last_activity': "TEXT NOT NULL"};

  /// Serializes the session into its standard JSON representation.
  ///
  /// Includes the model UUID, email, token, and timestamp metadata.
  ///
  /// Returns a map suitable for storage or transport.
  ///
  /// Example:
  /// ```dart
  /// final json = session.toJson();
  /// print(json['email']);
  /// print(json['token']);
  /// ```
  @override
  Map<String, dynamic> toJson() {
    return {
      "uuid": uuid,
      "token": token,
      'last_activity': lastActivity.toIso8601String(),
      "created_at": createdAt?.toIso8601String(),
      "updated_at": updatedAt?.toIso8601String(),
      "data": data,
      "user": user?.toJson(),
      "errors": errors,
      "flashMessages": flashMessages,
    };
  }

  @override
  Map<String, dynamic> toMetaJson() {
    return {
      "id": id,
      "uuid": uuid,
      "token": token,
      'last_activity': lastActivity.toIso8601String(),
      "created_at": createdAt?.toIso8601String(),
      "updated_at": updatedAt?.toIso8601String(),
    };
  }

  static Session? _checkContainer(String cookieValue) {
    return _containerSessions?.firstWhereOrNull((session) => session.token == cookieValue);
  }

  static Future<Session?> _checkDB(String cookieValue) async {
    return await Model.firstWhere<Session>(field: "token", value: cookieValue);
  }

  /// Persists a fresh guest session and exposes its cookie to this request
  /// and the browser response.
  static Future<Session> _createNewSession(HttpRequest request) async {
    final cookie = Cookie('archery_guest_session', App.generateKey())
      ..httpOnly = true
      ..secure = true
      ..sameSite = SameSite.lax;

    final session = Session(token: cookie.value);
    await session.save();

    _containerSessions?.add(session);
    request.cookies.add(cookie);
    request.response.cookies.add(cookie);
    return session;
  }

  /// Accepts sessions whose last activity was less than one hour ago.
  static bool _validateSession(Session session) {
    final currentTime = DateTime.now();
    final difference = currentTime.difference(session.lastActivity);
    return difference.inHours < 1;
  }
}

/// Alias for [GuestSession].
///
/// This is typically used as a middleware guard for pages like login/register
/// (redirect authenticated users away from guest-only pages).
typedef Guest = GuestSession;

/// Restricts routes such as login and registration to unauthenticated visitors.
class GuestSession {
  /// Redirects authenticated visitors to the dashboard; otherwise runs [next].
  static Future<dynamic> middleware(HttpRequest request, Future<void> Function() next) async {
    if (await Auth.check(request)) {
      return request.redirectToDashboard();
    }

    await next();
  }
}

/// Alias for [AuthSession].
///
/// This allows concise usage at call sites: `Auth.user(request)`, `Auth.check(request)`.
typedef Auth = AuthSession;


/// Represents an authenticated user session backed by both persistent storage
/// and an in-memory session registry.
///
/// An `AuthSession` stores the authenticated user's email, a session token,
/// the timestamp of the most recent activity, and the request cookie currently
/// associated with the session.
///
/// This model is used to:
/// - persist session records
/// - resolve the current authenticated user from an HTTP request
/// - validate session freshness
/// - manage login and logout flows
///
/// Fields:
/// - `email`: Email address of the authenticated user.
/// - `token`: Persistent session token stored with the record.
/// - `lastActivity`: Tracks recent activity for idle-timeout validation.
///
/// Example:
/// ```dart
/// final session = AuthSession(email: 'jane@example.com');
/// ```
class AuthSession extends Model with InstanceDatabaseOps<AuthSession> {
  late String email;
  late String token;
  late DateTime lastActivity = DateTime.now();

  /// Creates an unsaved session; its token must be assigned before serialization.
  AuthSession({required this.email}) : super.fromJson({});

  /// Optional shared cache registered in the application container.
  static List<AuthSession>? get _cachedSessions {
    return App().tryMake<List<AuthSession>>();
  }

  /// Creates an `AuthSession` from a JSON map.
  ///
  /// Expected keys:
  /// - `email`
  /// - `token`
  ///
  /// Values are assigned only when present and of the expected type.
  ///
  /// Example:
  /// ```dart
  /// final session = AuthSession.fromJson({
  ///   'email': 'jane@example.com',
  ///   'token': 'session_token_123',
  /// });
  ///
  /// print(session.email); // jane@example.com
  /// print(session.token); // session_token_123
  /// ```
  AuthSession.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    if (json['email'] != null && json['email'] is String) {
      email = json['email'];
    }
    if (json['token'] != null && json['token'] is String) {
      token = json['token'];
    }
  }

  /// Serializes the session into its public-oriented JSON representation.
  ///
  /// Includes the model UUID, email, token, and timestamp metadata.
  ///
  /// Returns a map suitable for storage or transport.
  ///
  /// Example:
  /// ```dart
  /// final json = session.toJson();
  /// print(json['email']);
  /// print(json['token']);
  /// ```
  @override
  Map<String, dynamic> toJson() {
    return {"uuid": uuid, "email": email, 'token': token, "created_at": createdAt?.toIso8601String(), "updated_at": updatedAt?.toIso8601String()};
  }

  /// Serializes the session into a DB-oriented JSON representation.
  ///
  /// This form includes the database `id` in addition to the standard session
  /// fields and timestamp metadata.
  ///
  /// Returns a map useful for administrative or internal inspection.
  ///
  /// Example:
  /// ```dart
  /// final meta = session.toMetaJson();
  /// print(meta['id']);
  /// print(meta['uuid']);
  /// print(meta['email']);
  /// ```
  @override
  Map<String, dynamic> toMetaJson() {
    return {"id": id, "uuid": uuid, 'email': email, 'token': token, "created_at": createdAt?.toIso8601String(), "updated_at": updatedAt?.toIso8601String()};
  }

  /// Defines the database columns required for persisting auth sessions.
  ///
  /// Both `email` and `token` are required text fields.
  ///
  /// Example:
  /// ```dart
  /// final columns = AuthSession.columnDefinitions;
  /// print(columns['email']); // TEXT NOT NULL
  /// print(columns['token']); // TEXT NOT NULL
  /// ```
  static Map<String, String> columnDefinitions = {'email': 'TEXT NOT NULL', 'token': 'TEXT NOT NULL'};

  /// Validates whether the given session is still active.
  ///
  /// A session is considered valid when its last recorded activity occurred
  /// less than one hour ago.
  ///
  /// Returns `true` for active sessions and `false` for expired sessions.
  ///
  /// Example:
  /// ```dart
  /// final isValid = AuthSession._validateSession(session);
  /// print(isValid);
  /// ```
  static bool _validateSession(AuthSession session) {
    final currentTime = DateTime.now();
    final difference = currentTime.difference(session.lastActivity);
    return difference.inHours < 1;
  }

  static AuthSession? _checkContainer(String cookieValue) {
    return _cachedSessions?.firstWhereOrNull((session) => session.token == cookieValue);
  }

  static Future<AuthSession?> _checkDB(String cookieValue) async {
    return await Model.firstWhere<AuthSession>(field: "token", value: cookieValue);
  }

  /// Resolves the currently authenticated user from the incoming request.
  ///
  /// Workflow:
  /// 1. Reads the `archery_session` cookie from the request.
  /// 2. Looks up the matching in-memory and db sessions.
  /// 3. Verifies the session is still valid.
  /// 4. Updates the session activity timestamp.
  /// 5. Loads and returns the corresponding `User` record.
  ///
  /// If any step fails, the request is logged out and `null` is returned.
  ///
  /// Returns the authenticated `User`, or `null` when authentication fails.
  ///
  /// Example:
  /// ```dart
  /// final currentUser = await Auth.user(request);
  ///
  /// if (currentUser != null) {
  ///   print('Authenticated as ${currentUser.email}');
  /// }
  /// ```
  static Future<User?> user(HttpRequest request) async {
    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");

    if (cookie == null) {
      return null;
    }

    final containerSession = _checkContainer(cookie.value);
    if (containerSession != null) {
      if (!_validateSession(containerSession)) {
        await logout(request);
        return null;
      }

      containerSession.lastActivity = DateTime.now();
      await containerSession.save();

      return await Model.firstWhere<User>(field: "email", value: containerSession.email);
    }

    final sessionRecord = await _checkDB(cookie.value);
    if (sessionRecord != null) {
      if (!_validateSession(sessionRecord)) {
        await logout(request);
        return null;
      }

      sessionRecord.lastActivity = DateTime.now();
      _cachedSessions?.add(sessionRecord);

      await sessionRecord.save();

      return await Model.firstWhere<User>(field: "email", value: sessionRecord.email);
    }

    return null;
  }

  /// Determines whether the request is currently authenticated.
  ///
  /// This checks the session record without looking up the associated user.
  ///
  /// Example:
  /// ```dart
  /// if (await Auth.check(request)) {
  ///   print('User is authenticated');
  /// } else {
  ///   print('Guest request');
  /// }
  /// ```
  static Future<bool> check(HttpRequest request) async {
    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");

    if (cookie == null) {
      return false;
    }

    final containerSession = _checkContainer(cookie.value);
    if (containerSession != null) {
      if (!_validateSession(containerSession)) {
        await logout(request);
        return false;
      }

      containerSession.lastActivity = DateTime.now();
      return await containerSession.save();
    }

    final sessionRecord = await _checkDB(cookie.value);
    if (sessionRecord != null) {
      if (!_validateSession(sessionRecord)) {
        await logout(request);
        return false;
      }
      sessionRecord.lastActivity = DateTime.now();
      _cachedSessions?.add(sessionRecord);
      return await sessionRecord.save();
    }

    return false;
  }

  /// Middleware that protects routes requiring authentication.
  ///
  /// This middleware:
  /// - verifies the session cookie exists
  /// - ensures an in-memory/db session is available
  /// - checks that the session matches the cookie
  /// - validates the session timeout window
  /// - refreshes the last-activity timestamp before continuing
  ///
  /// When validation fails, the request is logged out and redirected to the
  /// login flow.
  ///
  /// Parameters:
  /// - `request`: The incoming HTTP request.
  /// - `next`: The next middleware or handler in the pipeline.
  ///
  /// Example:
  /// ```dart
  /// router.get(
  ///   '/dashboard',
  ///   handler: (request) async => dashboardController.index(request),
  ///   middleware: [Auth.middleware],
  /// );
  /// ```
  static Future<dynamic> middleware(HttpRequest request, Future<void> Function() next) async {
    if (await check(request)) {
      return await next();
    }

    return request.redirectToLogin();
  }

  /// Logs in with form credentials, or an existing cookie when [usingCookie].
  static Future<bool> login(HttpRequest request, {bool usingCookie = false}) async {
    try {
      if (usingCookie) {
        return await loginWithCookie(request);
      }

      final email = await request.form.input('email');
      final password = await request.form.input('password');

      return await loginWithEmailAndPassword(request, email: email, password: password);
    } catch (e) {
      return false;
    }
  }

  /// Creates a new session for the user resolved from the current cookie.
  ///
  /// Issues a fresh token without deleting the previous session record.
  /// Returns `false` when no user is resolved or session creation fails.
  static Future<bool> loginWithCookie(HttpRequest request) async {
    try {
      final authUser = await user(request);

      if (authUser != null) {
        final cookie = Cookie('archery_session', App.generateKey())
          ..httpOnly = true
          ..secure = true
          ..sameSite = SameSite.lax;

        final newAuthSession = await Model.create<AuthSession>(fromJson: {"email": authUser.email, "token": cookie.value});

        if (newAuthSession == null) return false;

        newAuthSession.lastActivity = DateTime.now();
        _cachedSessions?.add(newAuthSession);

        request.response.cookies.add(cookie);
        request.cookies.add(cookie);

        return await newAuthSession.save();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Verifies credentials and issues a new authentication cookie.
  ///
  /// Requires a registered session cache and rejects already authenticated
  /// requests. Multiple sessions may share an email, each with its own token.
  static Future<bool> loginWithEmailAndPassword(HttpRequest request, {required String email, required String password}) async {
    try {
      if (_cachedSessions == null) {
        return false;
      }

      if (await check(request)) {
        return false;
      }

      // < v1.6 allowed for only one authSession per email.
      // now allowing multiple... will base on cookie value

      // use check to limit login sessions

      // final sessions = await Model.where<AuthSession>(field: "email", value: email);
      //
      // if( sessions.length >= 5 ) {
      //   return false;
      // }

      final user = await Model.firstWhere<User>(field: "email", value: email);

      if (user != null && Hasher.check(key: password, hash: user.password)) {
        final cookie = Cookie('archery_session', App.generateKey())
          ..httpOnly = true
          ..secure = true
          ..sameSite = SameSite.lax;

        final newAuthSession = await Model.create<AuthSession>(fromJson: {"email": user.email, "token": cookie.value});

        if (newAuthSession == null) return false;

        newAuthSession.lastActivity = DateTime.now();
        _cachedSessions?.add(newAuthSession);

        request.response.cookies.add(cookie);
        request.cookies.add(cookie);

        return await newAuthSession.save();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Deletes the matching authentication session and clears guest-session state.
  ///
  /// Removes the cookie from request/response collections; it does not emit an
  /// expired browser cookie. A missing cookie succeeds, while an unknown token
  /// or a failed deletion returns `false`.

  static Future<bool> logout(HttpRequest request) async {
    try {
      final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");

      if (cookie == null) {
        return true;
      }

      final containerSession = _checkContainer(cookie.value);

      if (containerSession != null) {
        _cachedSessions?.remove(containerSession);
        request.cookies.remove(cookie);
        request.response.cookies.remove(cookie);
        request.thisSession?.user = null;
        request.thisSession?.data.clear();
        request.thisSession?.errors.clear();
        request.thisSession?.flashMessages.clear();
        return await containerSession.delete();
      }

      final dbSession = await _checkDB(cookie.value);

      if (dbSession != null) {
        request.cookies.remove(cookie);
        request.response.cookies.remove(cookie);
        request.thisSession?.user = null;
        request.thisSession?.data.clear();
        request.thisSession?.errors.clear();
        request.thisSession?.flashMessages.clear();
        return await dbSession.delete();
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}


/// Adds password hashing helpers related to authentication.
///
/// This extension centralizes password hashing and verification behavior
/// through the framework's `Hasher` implementation.
extension PasswordHashing on Auth {
  /// Hashes a plain-text password for secure storage.
  ///
  /// Parameters:
  /// - `key`: The plain-text password to hash.
  ///
  /// Returns the generated password hash.
  ///
  /// Example:
  /// ```dart
  /// final hash = Auth.hashPassword(key: 'super-secret-password');
  /// print(hash);
  /// ```
  static String hashPassword({required String key}) {
    return Hasher.make(key: key);
  }

  /// Verifies a plain-text password against a stored hash.
  ///
  /// Parameters:
  /// - `key`: The plain-text password to verify.
  /// - `hash`: The stored password hash.
  ///
  /// Returns `true` when the password matches the hash; otherwise `false`.
  ///
  /// Example:
  /// ```dart
  /// final hash = Auth.hashPassword(key: 'super-secret-password');
  /// final matches = Auth.verifyPassword(
  ///   key: 'super-secret-password',
  ///   hash: hash,
  /// );
  ///
  /// print(matches); // true
  /// ```
  static bool verifyPassword({required String key, String? hash}) {
    return Hasher.check(key: key, hash: hash);
  }
}

/// Registers Archery's built-in authentication routes onto the provided [router].
///
/// Routes include:
/// - `GET  /login` (guest-only)
/// - `POST /login`
/// - `GET  /register` (guest-only)
/// - `POST /register`
///
/// These routes assume the bundled auth views exist (e.g. `auth.login`, `auth.register`)
/// and that the `User` model is available for persistence.
void authRoutes(Router router) {
  router.group(
    routes: () {
      router.get('/login', middleware: [Guest.middleware], (request) async {
        return request.view("auth.login");
      });

      router.get('/register', middleware: [Guest.middleware], (request) async {
        return request.view("auth.register");
      });

      router.post('/register', (request) async {
        try {
          final validated = await request.validateAll([
            {
              "email": [Rule.required, Rule.max(255), Rule.email, Rule.unique<User>(column: "email")],
            },
            {
              "name": [Rule.required, Rule.min(3), Rule.max(100)],
            },
            {
              "password": [Rule.required, Rule.min(6), Rule.max(50)],
            },
          ]);

          if (!validated) {
            return request.redirectBack();
          }

          final name = await request.form.input('name');
          final email = await request.form.input('email');
          final password = await request.form.input('password');

          final userRecord = await Model.firstWhere<User>(field: "email", value: email);

          if (userRecord != null) {
            request.flash(key: "error", message: "User exists");
            return request.redirectToLogin();
          }

          final user = User(name: name, email: email, password: password);
          await user.save();
          request.flash(key: "success", message: "Account created");
          return request.redirectToLogin();
        } catch (e, stack) {
          App().archeryLogger.error("Registration error", {"origin": "authRoutes post /register", "error": e.toString(), "stack": stack.toString()});
          request.flash(key: "error", message: "Something went wrong");
          return request.redirectBack();
        }
      });

      router.post('/login', (request) async {
        try {
          final validated = await request.validateAll([
            {
              "email": [Rule.required, Rule.email, Rule.max(255)],
            },
            {
              "password": [Rule.required, Rule.max(50)],
            },
          ]);

          if (!validated) {
            return request.redirectBack();
          }

          if (await Auth.login(request)) {
            return request.redirectToDashboard();
          }

          request.flash(key: "error", message: "Invalid credentials");
          return request.redirectBack();
        } catch (e, stack) {
          App().archeryLogger.error("Login error", {"origin": "authRoutes post /login", "error": e.toString(), "stack": stack.toString()});
          request.flash(key: "error", message: "Invalid credentials");
          return request.redirectBack();
        }
      });

      router.get('/logout', (request) async {
        await Auth.logout(request);
        return request.redirectHome();
      });

      router.group(
        prefix: "/user",
        middleware: [Auth.middleware],
        routes: () {
          // - grouped for profile & dashboard crud endpoints
          router.group(
            prefix: "/profile",
            routes: () {
              router.get("/", (request) async {
                return await request.view("auth.user.profile");
              });
            },
          );

          router.group(
            prefix: "/dashboard",
            routes: () {
              router.get("/", (request) async {
                return await request.view("auth.user.dashboard");
              });
            },
          );
        },
      );
    },
  );
}
