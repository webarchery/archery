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

/// Alias for [AuthSession].
///
/// This allows concise usage at call sites: `Auth.user(request)`, `Auth.check(request)`.
typedef Auth = AuthSession;

/// Alias for [GuestSession].
///
/// This is typically used as a middleware guard for pages like login/register
/// (redirect authenticated users away from guest-only pages).
typedef Guest = GuestSession;

/// Guest session record used for unauthenticated visitors.
///
/// Archery uses this model to track a visitor session token (stored in the
/// `archery_guest_session` cookie) and last activity timestamp. This guest
/// session is also used as the binding point for CSRF token association.
class Session extends Model with InstanceDatabaseOps<Session> {
  late String token;
  late DateTime lastActivity = DateTime.now();

  Map<String, dynamic> data = {};
  Map<String, dynamic> errors = {};
  Map<String, dynamic> flashMessages = {};

  User? user;

  // set in view engine
  String? csrf;

  Session({required this.token}) : super.fromJson({});


  static Future<Session?> init(HttpRequest request) async {


    if(request.uri.path.startsWith('/api/')) {
      return null;
    }



    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_guest_session");
    final sessions = App().tryMake<List<Session>>();

    if (cookie == null) {
      final session = Session(token: App.generateKey());
      await session.save();
      sessions?.add(session);
      request.cookies.add(Cookie("archery_guest_session", session.token));
      request.response.cookies.add(Cookie("archery_guest_session", session.token));
      return session;
    } else {
      final session = sessions?.firstWhereOrNull((session) => session.token == cookie.value);
      if (session != null) {
        session.lastActivity = DateTime.now();
        await session.save();
        request.cookies.add(Cookie("archery_guest_session", session.token));
        request.response.cookies.add(Cookie("archery_guest_session", session.token));
        return session;
      }
    }

    if (sessions != null && sessions.isEmpty) {
      final sessionRecord = await Model.firstWhere<Session>(field: "token", value: cookie.value);

      if (sessionRecord != null) {
        sessionRecord.lastActivity = DateTime.now();
        await sessionRecord.save();
        sessions.add(sessionRecord);
        request.cookies.add(Cookie("archery_guest_session", sessionRecord.token));
        request.response.cookies.add(Cookie("archery_guest_session", sessionRecord.token));
        return sessionRecord;
      } else {
        final session = Session(token: App.generateKey());
        await session.save();
        sessions.add(session);
        request.cookies.add(Cookie("archery_guest_session", session.token));
        request.response.cookies.add(Cookie("archery_guest_session", session.token));
        return session;
      }
    }

    return null;
  }

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

  static Map<String, String> columnDefinitions = {'token': 'TEXT NOT NULL', 'last_activity': "TEXT NOT NULL"};

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
}

/// Middleware guard for routes intended only for *guests* (unauthenticated users).
///
/// If an auth session exists for the current request, the request is redirected
/// to the dashboard. Otherwise the request continues.
class GuestSession {
  static Future<dynamic> middleware(HttpRequest request, Future<void> Function() next) async {
    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");
    final authSessions = App().tryMake<List<AuthSession>>();

    if (cookie == null || authSessions == null || authSessions.isEmpty) {
      await next();
      return;
    }

    final session = authSessions.firstWhereOrNull((session) => session.cookie?.value == cookie.value);

    if (session != null) {
      return request.redirectToDashboard();
    }

    await next();
  }
}

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
/// - `cookie`: In-memory cookie associated with the active request session.
///
/// Example:
/// ```dart
/// final session = AuthSession(email: 'jane@example.com');
/// ```
class AuthSession extends Model with InstanceDatabaseOps<AuthSession> {
  late String email;
  late String token;
  late DateTime lastActivity = DateTime.now();
  Cookie? cookie;

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

  /// Creates a new `AuthSession` instance for the given email.
  ///
  /// This constructor initializes the model from an empty JSON payload and is
  /// typically used when preparing a new session instance before persistence.
  ///
  /// Example:
  /// ```dart
  /// final session = AuthSession(email: 'jane@example.com');
  /// print(session.email); // jane@example.com
  /// ```
  AuthSession({required this.email}) : super.fromJson({});

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
    return {"uuid": uuid, "email": email, 'token': token, "created_at": createdAt?.toIso8601String(), "updated_at": updatedAt?.toIso8601String()};
  }

  /// Serializes the session into a metadata-oriented JSON representation.
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

  /// Resolves the currently authenticated user from the incoming request.
  ///
  /// Workflow:
  /// 1. Reads the `archery_session` cookie from the request.
  /// 2. Looks up the matching in-memory session.
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
  /// final currentUser = await AuthSession.user(request);
  ///
  /// if (currentUser != null) {
  ///   print('Authenticated as ${currentUser.email}');
  /// }
  /// ```
  static Future<User?> user(HttpRequest request) async {
    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");
    if (cookie == null) {
      await logout(request);
      return null;
    }

    final authSessions = App().tryMake<List<AuthSession>>();

    if (authSessions == null || authSessions.isEmpty) {
      await logout(request);
      return null;
    }

    final session = authSessions.firstWhereOrNull((session) => session.cookie?.value == cookie.value);

    if (session == null) {
      await logout(request);
      return null;
    }

    if (!_validateSession(session)) {
      await logout(request);
      return null;
    }

    session.lastActivity = DateTime.now();

    final sessionRecord = await Model.firstWhere<AuthSession>(field: "email", value: session.email);

    if (sessionRecord != null) {
      return await Model.firstWhere<User>(field: "email", value: sessionRecord.email);
    }
    return null;
  }

  /// Determines whether the request is currently authenticated.
  ///
  /// This is a convenience wrapper around [user].
  ///
  /// Returns `true` when a valid authenticated user can be resolved;
  /// otherwise returns `false`.
  ///
  /// Example:
  /// ```dart
  /// if (await AuthSession.check(request)) {
  ///   print('User is authenticated');
  /// } else {
  ///   print('Guest request');
  /// }
  /// ```
  static Future<bool> check(HttpRequest request) async {
    return await user(request) != null;
  }

  /// Logs out the current session associated with the request.
  ///
  /// This method attempts to:
  /// - locate the current session cookie
  /// - remove the corresponding persisted session record
  /// - remove the session from the in-memory registry
  /// - clear the user bound to the current request session
  ///
  /// Returns `true` if a matching session was found and removed; otherwise
  /// returns `false`.
  ///
  /// Any exception during logout results in `false`.
  ///
  /// Example:
  /// ```dart
  /// final didLogout = await AuthSession.logout(request);
  ///
  /// if (didLogout) {
  ///   print('Session ended successfully');
  /// }
  /// ```
  static Future<bool> logout(HttpRequest request) async {
    try {
      final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");
      final authSessions = App().tryMake<List<AuthSession>>();

      final session = authSessions?.firstWhereOrNull((session) => session.cookie?.value == cookie?.value);

      if (session != null) {
        final sessionRecord = await Model.firstWhere<AuthSession>(field: "email", value: session.email);
        await sessionRecord?.delete();
        authSessions?.remove(session);
        request.thisSession?.user = null;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Attempts to authenticate a user and establish a session.
  ///
  /// Behavior:
  /// - Creates a secure, HTTP-only session cookie.
  /// - Reuses an existing in-memory session when available for the email.
  /// - Otherwise verifies the user's password and creates a new persisted
  ///   session record.
  /// - Registers the session in memory and attaches the cookie to the response.
  ///
  /// Parameters:
  /// - `request`: The active HTTP request.
  /// - `email`: The user's email address.
  /// - `password`: The plain-text password to verify.
  ///
  /// Returns `true` when login succeeds; otherwise returns `false`.
  ///
  /// Example:
  /// ```dart
  /// final success = await AuthSession.login(
  ///   request: request,
  ///   email: 'jane@example.com',
  ///   password: 'super-secret-password',
  /// );
  ///
  /// if (success) {
  ///   print('Login successful');
  /// }
  /// ```
  static Future<bool> login({required HttpRequest request, required String email, required String password}) async {
    try {
      final cookie = Cookie('archery_session', App.generateKey())
        ..httpOnly = true
        ..secure = true
        ..sameSite = SameSite.lax;

      final authSessions = App().tryMake<List<AuthSession>>();
      if (authSessions == null) return false;

      final authSession = authSessions.firstWhereOrNull((session) => session.email == email);

      if (authSession != null) {
        request.response.cookies.add(cookie);
        authSession.cookie = cookie;
        authSession.lastActivity = DateTime.now();
        return true;
      } else {
        final user = await Model.firstWhere<User>(field: "email", value: email);

        if (user != null && Hasher.check(key: password, hash: user.password)) {
          final newAuthSession = await Model.create<AuthSession>(fromJson: {"email": user.email, "token": App.generateKey()});
          if (newAuthSession == null) return false;

          newAuthSession.lastActivity = DateTime.now();
          newAuthSession.cookie = cookie;
          authSessions.add(newAuthSession);

          request.response.cookies.add(cookie);

          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Middleware that protects routes requiring authentication.
  ///
  /// This middleware:
  /// - verifies the session cookie exists
  /// - ensures an in-memory session is available
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
  ///   middleware: [AuthSession.middleware],
  /// );
  /// ```
  static Future<dynamic> middleware(HttpRequest request, Future<void> Function() next) async {
    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");

    if (cookie == null) {
      await logout(request);
      return request.redirectToLogin();
    }

    final authSessions = App().tryMake<List<AuthSession>>();

    if (authSessions == null || authSessions.isEmpty) {
      await logout(request);
      return request.redirectToLogin();
    }

    final session = authSessions.firstWhereOrNull((session) => session.cookie?.value == cookie.value);

    if (session == null) {
      await logout(request);
      return request.redirectToLogin();
    }

    if (!_validateSession(session)) {
      await logout(request);
      return request.redirectToLogin();
    }

    session.lastActivity = DateTime.now();
    await next();
  }

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
          final validated = await request.validateAll([{
              "email": [
                Rule.required,
                Rule.email,
                Rule.max(255),
                Rule.unique<User>(column: "email")],}, {

              "name": [
                Rule.required,
                Rule.min(3),
                Rule.max(100)],},{

              "password": [
                Rule.required,
                Rule.min(6),
                Rule.max(50)],},]
          );

          if (!validated) {
            return request.redirectBack();
          }

          final form = request.form();
          final name = await form.input('name');
          final email = await form.input('email');
          final password = await form.input('password');

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
          final validated = await request.validateAll([{

              "email": [
                Rule.required,
                Rule.email,
                Rule.max(255)],},{

              "password": [
                Rule.required,
                Rule.max(50)],
            },
          ]);

          if (!validated) {
            return request.redirectBack();
          }

          final form = request.form();
          final email = await form.input('email');
          final password = await form.input('password');

          if (await Auth.login(request: request, email: email, password: password)) {
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
          // - grouped for profile & dashboard crud
          router.group(
            prefix: "/profile",
            routes: () {
              router.get("/", (request) async {
                return request.view("auth.user.profile");
              });
            },
          );

          router.group(
            prefix: "/dashboard",
            routes: () {
              router.get("/", (request) async {
                return request.view("auth.user.dashboard");
              });
            },
          );
        },
      );
    },
  );
}
