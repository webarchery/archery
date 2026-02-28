
---

# Archery

A Laravel-inspired, Dart-native web framework built directly on `dart:io`.

Archery is a **stable alpha / early-production framework** focused on clarity, explicit architecture, and batteries-included fundamentals:

* IoC container
* Provider-based lifecycle
* HTTP kernel + middleware pipeline
* Router with groups and typed parameters
* Blade-style templating
* Multi-driver ORM (JSON, SQLite, Postgres, S3)
* Session-based authentication
* CSRF protection
* Static file serving

Archery is suitable for real deployments, and is still actively hardening and evolving toward a 2.0 production-focused milestone.

---

## Philosophy

Archery aims to be:

* **Explicit over magical**
* **Framework, not micro-router**
* **Dart-native**
* **Readable and hackable**
* **Opinionated but small**

It does not wrap another server framework. It is built directly on `dart:io`.

---

# Architecture Overview

Archery follows a layered request lifecycle:

```
Incoming Request
   ↓
dart:io HTTP Server
   ↓
HTTP Kernel
   ↓
Middleware Pipeline
   ↓
Router
   ↓
Controller
   ↓
Response
```

Core architectural components:

* **Application** – central orchestrator
* **Service Providers** – register and boot services
* **IoC Container** – dependency resolution
* **HTTP Kernel** – request handling entry point
* **Middleware** – request/response pipeline
* **Router** – route matching and dispatch
* **Controllers** – application logic
* **Models** – ORM-backed data layer
* **Views** – templated HTML rendering

---

# Core Features

## HTTP Layer

* Route definitions by method
* Route groups
* Middleware chaining
* Typed route parameters
* Static file serving
* CORS middleware

Example:

```dart
router.get('/users/{id:int}', (req) async {
  final id = RouteParam.get<int>('id');
  return req.json({'id': id});
});
```

---

## Service Providers & IoC Container

Archery uses a provider model similar to Laravel:

```dart
class SomeServiceProvider extends Provider {
  @override
  void register() {
    container.bind<SomeService>((c) => SomeService());
  }

  @override
  void boot() {
    // Runs after all providers are registered
  }
}
```

The container supports dependency resolution across the framework.

---

## Authentication

Archery includes session-based authentication:

* Password hashing: **PBKDF2-HMAC-SHA256**
* Versioned hash format (`pbkdf2-sha256$iterations$salt$hash`)
* Constant-time hash comparison
* Login / logout helpers
* Auth session cookie

Authentication is built into the framework and integrated with sessions.

---

## Sessions

Archery supports:

* Guest sessions
* Authenticated sessions
* Server-side session storage
* Cookie-based session identifiers

Sessions are used for:

* Authentication
* CSRF token binding
* Flash data (if implemented)

---

## CSRF Protection

Archery includes CSRF middleware:

* Automatic token generation
* Token stored in session
* Token validation on state-changing requests
* `@csrf` template directive

Example:

```html
<form method="POST">
  @csrf
  ...
</form>
```

---

## ORM

Archery includes a built-in ORM with multiple drivers:

### Supported Drivers

* JSON (file-based)
* SQLite
* Postgres
* S3-backed model storage

### Features

* CRUD operations
* Relationships:

    * `belongsTo`
    * `hasMany`
    * `hasOne`
* Model mixins
* Adapter-based storage abstraction

Example:

```dart
class User extends Model {}

// uses default disk. in this e.g => .file
final user = await Model.find<User>(id: 1);

final user2 = await Model.find<User>(id: 1, disk: .sqlite);

final user3 = await Model.find<User>(id: 1, disk: .s3);

final user4 = await Model.find<User>(id: 1, disk: .pgsql);

final user5 = User(name: "Archer", email: "archer@example.com", passwprd: "password");

await user5.save();
await user5.save(disk: .sqlite);
```

Archery’s ORM is functional and production-capable, though still evolving in terms of advanced query features and edge-case coverage.

---

## Templating Engine

Blade-inspired templating:

* Layouts
* Includes
* Directives
* Escaped output
* `@csrf` directive

Designed for server-rendered applications.

---

# Security Model (Current State)

Archery currently provides:

* PBKDF2-based password hashing
* Constant-time hash comparison
* Session-based CSRF protection
* HttpOnly auth cookies
* Middleware-based request validation

### Production Recommendations

When deploying:

* Run behind HTTPS
* Enable secure cookie flags
* Use Postgres for production databases
* Configure body size limits
* Use reverse proxy (NGINX, Caddy, etc.)

Security hardening is an active focus toward the 2.0 milestone.

---

# Database Guidance

| Driver   | Recommended Use                |
| -------- |--------------------------------|
| JSON     | Local dev, small apps          |
| SQLite   | Small to medium apps           |
| Postgres | Production workloads           |
| S3       | Backups / Experimental / Niche |

---

# Minimal Application Example

```dart
Future<void> main() async {
  final app = App();
  
  await app.boot();
  
  final router = app.container.make<Router>();

  router.get('/', (req) async {
    return req.text('hello world');
  });


  final kernel = AppKernel(
    router: router,
  );

  try {
    HttpServer.bind(InternetAddress.loopbackIPv4, 5501).then((server) async {

      await for (HttpRequest request in server) {
        kernel.handle(request);
      }
    });
  } catch (e, stack) {
    print("Error booting server: $e\n$stack");
    await app.shutdown();
  }
  
  

}
```

---

# Production Status

Archery is currently:

**Stable Alpha / Early Production**

This means:

* Suitable for real deployments
* API mostly stable
* Internals still evolving
* Security hardening and test expansion ongoing
* ORM and middleware features expanding

If you are building mission-critical infrastructure, evaluate carefully and follow production recommendations.

---

# Contributing

Archery is actively evolving. Contributions, issues, and design discussions are welcome.

---

## License

**BSD-3-Clause**
See LICENSE file for details.
