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

typedef Auth = AuthSession;
typedef Guest = GuestSession;

class Session extends Model {
  late String token;
  late DateTime lastActivity = DateTime.now();

  // set in view engine
  String? csrf;

  Session({required this.token}) : super.fromJson({});

  static Future<Session?> init(HttpRequest request) async {
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
    return {"uuid": uuid, "token": token, 'last_activity': lastActivity.toIso8601String(), "created_at": createdAt?.toIso8601String(), "updated_at": updatedAt?.toIso8601String()};
  }

  @override
  Map<String, dynamic> toMetaJson() {
    return {"id": id, "uuid": uuid, "token": token, 'last_activity': lastActivity.toIso8601String(), "created_at": createdAt?.toIso8601String(), "updated_at": updatedAt?.toIso8601String()};
  }

  @override
  Future<bool> save({DatabaseDisk? disk}) async => await Model.saveInstance<Session>(instance: this, disk: disk ?? this.disk);

  @override
  Future<bool> delete({DatabaseDisk? disk}) async => await Model.deleteInstance<Session>(instance: this, disk: disk ?? this.disk);

  @override
  Future<bool> update({DatabaseDisk? disk}) async => await Model.updateInstance<Session>(instance: this, disk: disk ?? this.disk, withJson: toMetaJson());
}
class GuestSession {
  static Future<dynamic> middleware(HttpRequest request, void Function() next) async {
    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");
    final authSessions = App().tryMake<List<AuthSession>>();

    if (cookie == null || authSessions == null || authSessions.isEmpty) {
      return next();
    }

    final session = authSessions.firstWhereOrNull((session) => session.cookie?.value == cookie.value);

    if (session != null) return request.redirectToDashboard();

    return next();
  }
}


class AuthSession extends Model {
  late String email;
  late String token;
  late DateTime lastActivity = DateTime.now();
  Cookie? cookie;

  static Map<String, String> columnDefinitions = {'email': 'TEXT NOT NULL', 'token': 'TEXT NOT NULL'};

  AuthSession({required this.email}) : super.fromJson({});

  AuthSession.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    if (json['email'] != null && json['email'] is String) {
      email = json['email'];
    }
    if (json['token'] != null && json['token'] is String) {
      token = json['token'];
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {"uuid": uuid, "email": email, 'token': token, "created_at": createdAt?.toIso8601String(), "updated_at": updatedAt?.toIso8601String()};
  }

  @override
  Map<String, dynamic> toMetaJson() {
    return {"id": id, "uuid": uuid, 'email': email, 'token': token, "created_at": createdAt?.toIso8601String(), "updated_at": updatedAt?.toIso8601String()};
  }

  static Future<User?> user(HttpRequest request) async {
    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");
    final authSessions = App().tryMake<List<AuthSession>>();

    if (cookie == null || authSessions == null || authSessions.isEmpty) {
      return null;
    }

    final session = authSessions.firstWhereOrNull((session) => session.cookie?.value == cookie.value);

    if (session == null) return null;
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

  static Future<bool> check(HttpRequest request) async {
    return await user(request) != null;
  }

  static Future<bool> logout(HttpRequest request) async {
    try {
      final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");
      final authSessions = App().tryMake<List<AuthSession>>();

      final session = authSessions?.firstWhereOrNull((session) => session.cookie?.value == cookie?.value);

      if (session != null) {
        final sessionRecord = await Model.firstWhere<AuthSession>(field: "email", value: session.email);
        await sessionRecord?.delete();
        authSessions?.remove(session);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> login({required String email, required String password}) async {
    try {
      final authSessions = App().tryMake<List<AuthSession>>();
      if (authSessions == null) return false;

      final authSession = authSessions.firstWhereOrNull((session) => session.email == email);

      if (authSession != null) {
        authSession.lastActivity = DateTime.now();
        return true;
      } else {
        final user = await Model.firstWhere<User>(field: "email", value: email);

        if (user != null && Hasher.verifyPassword(password, user.password)) {
          final newAuthSession = await Model.create<AuthSession>(fromJson: {"email": user.email, "token": App.generateKey()});
          if (newAuthSession == null) return false;
          authSession?.lastActivity = DateTime.now();
          authSessions.add(newAuthSession);
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<dynamic> middleware(HttpRequest request, void Function() next) async {
    final cookie = request.cookies.firstWhereOrNull((cookie) => cookie.name == "archery_session");
    final authSessions = App().tryMake<List<AuthSession>>();

    if (cookie == null || authSessions == null || authSessions.isEmpty) {
      return request.redirectToLogin();
    }

    final session = authSessions.firstWhereOrNull((session) => session.cookie?.value == cookie.value);

    if (session == null) return request.redirectToLogin();

    if (!_validateSession(session)) {
      await logout(request);
      return request.redirectToLogin();
    }

    session.lastActivity = DateTime.now();
    return next();
  }

  @override
  Future<bool> save({DatabaseDisk? disk}) async => await Model.saveInstance<AuthSession>(instance: this, disk: disk ?? this.disk);

  @override
  Future<bool> delete({DatabaseDisk? disk}) async => await Model.deleteInstance<AuthSession>(instance: this, disk: disk ?? this.disk);

  @override
  Future<bool> update({DatabaseDisk? disk}) async => await Model.updateInstance<AuthSession>(instance: this, disk: disk ?? this.disk, withJson: toMetaJson());

  static bool _validateSession(AuthSession session) {
    final currentTime = DateTime.now();
    final difference = currentTime.difference(session.lastActivity);
    return difference.inHours < 1;
  }
}
void authRoutes(Router router) {

  router.get('/login', middleware: [Guest.middleware], (request) async {
    return request.view("auth.login");
  });

  router.get('/register', middleware: [Guest.middleware], (request) async {
    return request.view("auth.register");
  });

  router.post('/register', (request) async {
    try {
      final form = request.form();
      final name = await form.input('name');
      final email = await form.input('email');
      final password = await form.input('password');

      // Todo- form.validate(field as [.email, .phone, .name, .])
      // or use a FormValidator.validate()
      // opt 1 gives easy prototyping option
      // add a method on FormRequest
      // avoid extending Request, use buffered content and _request in FormRequest
      if (name == null || name.toString().isEmpty || email == null || email.toString().isEmpty || password == null || password.toString().isEmpty) {
        return request.redirectBack();
      }

      final userRecord = await Model.firstWhere<User>(field: "email", value: email);
      if (userRecord != null) return request.redirectBack();

      final user = User(name: name, email: email, password: password);
      await user.save();

      return request.redirectToLogin();
    } catch (e) {
      return request.redirectBack();
    }
  });

  router.post('/login', (request) async {
    try {
      final form = request.form();
      final email = await form.input('email');
      final password = await form.input('password');

      if (email == null || email.toString().isEmpty || password == null || password.toString().isEmpty) {
        return request.redirectBack();
      }

      if (await Auth.login(email: email, password: password)) {
        final cookie = Cookie('archery_session', App.generateKey())
          ..httpOnly = true
          ..secure =
              true // only over HTTPS
          ..sameSite = SameSite.lax;

        final sessions = App().container.tryMake<List<AuthSession>>();

        final session = sessions?.firstWhereOrNull((session) => session.email == email);
        if (session != null) {
          session.cookie = cookie;
          request.response.cookies.add(cookie);
        }
        return request.redirectToDashboard();
      }

      return request.redirectBack();
    } catch (e) {
      return request.redirectBack();
    }
  });

  router.get('/logout', (request) async {
    await Auth.logout(request);
    return request.redirectHome();
  });

  router.group(prefix: "/user", middleware: [Auth.middleware], routes: () {
      // - grouped for profile & dashboard crud
      router.group(prefix: "/profile", routes: () {
          router.get("/", (request) async {
            return request.view("auth.user.profile");
          });
        },
      );

      router.group(prefix: "/dashboard", routes: () {
          router.get("/", (request) async {
            return request.view("auth.user.dashboard");
          });
        },
      );
    },
  );
}
