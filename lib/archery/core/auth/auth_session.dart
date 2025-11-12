import 'package:archery/archery/archery.dart';

typedef Auth = AuthSession;
typedef Guest = GuestSession;

class GuestSession {
  static Future<dynamic> middleware(
    HttpRequest request,
    void Function() next,
  ) async {
    final cookie = request.cookies.firstWhereOrNull(
      (cookie) => cookie.name == "archery_session",
    );
    final authSessions = App().tryMake<List<AuthSession>>();

    if (cookie == null || authSessions == null || authSessions.isEmpty)
      return next();

    final session = authSessions.firstWhereOrNull(
      (session) => session.cookie?.value == cookie.value,
    );

    if (session != null) return request.redirectToDashboard();

    return next();
  }
}

class AuthSession extends Model {
  late String email;
  late String token;
  late DateTime lastActivity = DateTime.now();
  Cookie? cookie;

  static Map<String, String> columnDefinitions = {
    'email': 'TEXT NOT NULL',
    'token': 'TEXT NOT NULL',
  };

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
    return {
      "uuid": uuid,
      "email": email,
      'token': token,
      "created_at": createdAt?.toIso8601String(),
      "updated_at": updatedAt?.toIso8601String(),
    };
  }

  @override
  Map<String, dynamic> toMetaJson() {
    return {
      "id": id,
      "uuid": uuid,
      'email': email,
      'token': token,
      "created_at": createdAt?.toIso8601String(),
      "updated_at": updatedAt?.toIso8601String(),
    };
  }

  static Future<User?> user(HttpRequest request) async {
    final cookie = request.cookies.firstWhereOrNull(
      (cookie) => cookie.name == "archery_session",
    );
    final authSessions = App().tryMake<List<AuthSession>>();

    if (cookie == null || authSessions == null || authSessions.isEmpty)
      return null;

    final session = authSessions.firstWhereOrNull(
      (session) => session.cookie?.value == cookie.value,
    );

    if (session == null) return null;
    if (!_validateSession(session)) {
      await logout(request);
      return null;
    }
    session.lastActivity = DateTime.now();

    // Todo - implement eager-loading and relationships (planned)
    // api
    // session?.user.email => if there's a session, a user led to it's creation
    // user.session?.lastActivity => does this user have an active session?
    final sessionRecord = await Model.firstWhere<AuthSession>(
      field: "email",
      value: session.email,
    );

    if (sessionRecord != null) {
      return await Model.firstWhere<User>(
        field: "email",
        value: sessionRecord.email,
      );
    }
    return null;
  }

  static Future<bool> check(HttpRequest request) async {
    return await user(request) != null;
  }

  static Future<bool> logout(HttpRequest request) async {
    try {
      final cookie = request.cookies.firstWhereOrNull(
        (cookie) => cookie.name == "archery_session",
      );
      final authSessions = App().tryMake<List<AuthSession>>();

      final session = authSessions?.firstWhereOrNull(
        (session) => session.cookie?.value == cookie?.value,
      );

      if (session != null) {
        final sessionRecord = await Model.firstWhere<AuthSession>(
          field: "email",
          value: session.email,
        );
        await sessionRecord?.delete();
        authSessions?.remove(session);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      final authSessions = App().tryMake<List<AuthSession>>();
      if (authSessions == null) return false;

      final authSession = authSessions.firstWhereOrNull(
        (session) => session.email == email,
      );

      if (authSession != null) {
        authSession.lastActivity = DateTime.now();
        return true;
      } else {
        final user = await Model.firstWhere<User>(field: "email", value: email);

        if (user != null && Hasher.verifyPassword(password, user.password)) {
          final newAuthSession = await Model.create<AuthSession>(
            fromJson: {"email": user.email, "token": App.generateKey()},
          );
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

  static Future<dynamic> middleware(
    HttpRequest request,
    void Function() next,
  ) async {
    final cookie = request.cookies.firstWhereOrNull(
      (cookie) => cookie.name == "archery_session",
    );
    final authSessions = App().tryMake<List<AuthSession>>();

    if (cookie == null || authSessions == null || authSessions.isEmpty)
      return request.redirectToLogin();

    final session = authSessions.firstWhereOrNull(
      (session) => session.cookie?.value == cookie.value,
    );

    if (session == null) return request.redirectToLogin();

    if (!_validateSession(session)) {
      await logout(request);
      return request.redirectToLogin();
    }

    session.lastActivity = DateTime.now();
    return next();
  }

  @override
  Future<bool> save({Disk? disk}) async =>
      await Model.saveInstance<AuthSession>(
        instance: this,
        disk: disk ?? this.disk,
      );
  @override
  Future<bool> delete({Disk? disk}) async =>
      await Model.deleteInstance<AuthSession>(
        instance: this,
        disk: disk ?? this.disk,
      );
  @override
  Future<bool> update({Disk? disk}) async =>
      await Model.updateInstance<AuthSession>(
        instance: this,
        disk: disk ?? this.disk,
        withJson: toMetaJson(),
      );

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

  router.post('/register', middleware: [Guest.middleware], (request) async {
    try {
      final name = await request.input("name");
      final email = await request.input("email");
      final password = await request.input("password");

      if (name == null ||
          name.toString().isEmpty ||
          email == null ||
          email.toString().isEmpty ||
          password == null ||
          password.toString().isEmpty) {
        return request.redirectBack();
      }

      final userRecord = await Model.firstWhere<User>(
        field: "email",
        value: email,
      );
      if (userRecord != null) return request.redirectBack();

      final user = User(name: name, email: email, password: password);
      if (await user.save()) {
        await Auth.login(email: user.email, password: password);
        return request.redirectToDashboard();
      }

      return request.redirectBack();
    } catch (e) {
      return request.redirectBack();
    }
  });

  router.post('/login', (request) async {
    try {
      final email = await request.input("email");
      final password = await request.input("password");

      if (email == null ||
          email.toString().isEmpty ||
          password == null ||
          password.toString().isEmpty) {
        return request.redirectBack();
      }

      if (await Auth.login(email: email, password: password)) {
        final cookie = Cookie('archery_session', App.generateKey())
          ..httpOnly = true
          ..secure =
              true // only over HTTPS
          ..sameSite = SameSite.lax;

        final sessions = App().container.tryMake<List<AuthSession>>();

        final session = sessions?.firstWhereOrNull(
          (session) => session.email == email,
        );
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
}
