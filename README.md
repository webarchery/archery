# Archery — A Modern Web Framework for Dart

  <em>Laravel‑inspired developer flow. Dart‑native performance. Minimal, composable primitives.</em>


<p >
  <a href="https://github.com/webarchery/archery/blob/main/LICENSE">BSD License</a> •
  <a href="https://webarchery.dev">Website</a> •
  <a href="#roadmap">Roadmap</a>
</p>

---

## Why Archery

Archery reimagines backend development in **Dart** with a small set of predictable building blocks:

* **Predictable** – explicit, type‑safe APIs. No hidden magic.
* **Minimal** – keep the surface area tiny; build only what’s needed.
* **Composable** – IoC container + providers let features snap together.
* **Fast** – built directly on `dart:io` for zero overhead.

> Goal: make backend programming in Dart as expressive as Laravel/Adonis—**with compiler‑level benefits** and a clean standard library.

---

## Status

Version 1.0.0 Early Release.

---

## Quick Start

### 1) Clone & run

```bash
git clone https://github.com/webarchery/archery.git
cd archery
dart run bin/server.dart
```
Now visit -> localhost:5501

> Tip: if you just want to try it inside another project, add `archery` as a path dependency in your `pubspec.yaml` while experimenting.

### 2) Hello World route

Create `lib/http/routes/web.dart` (or use your existing routing file):

```dart
import 'dart:io';
import 'package:archery/archery.dart';

void webRoutes(Router router) {


  router.get('/', (request) async {
    return request.view("welcome", {});
  });
  
  router.get('/hello-world', (request) async {
    return request.text("Hello world!", {});
  });

  router.group(prefix: 'blog', routes: () {
    router.get('/', BlogPagesController.index);
    router.get('/{slug:string}',BlogPagesController.show);
  });
}
```

Wire routes in your app entry (`bin/server.dart`):



---

## Concepts at a glance

| Concept              | What it is                                                   | Why it matters                         |
| -------------------- | ------------------------------------------------------------ | -------------------------------------- |
| **App**              | The composition root that wires providers and boots the app. | Centralized lifecycle & configuration. |
| **ServiceContainer** | Lightweight IoC for factories/singletons/scopes.             | Predictable dependency management.     |
| **Provider**         | Registers and boots features (e.g., Router, DB).             | Clear module boundaries.               |
| **Router**           | Type‑safe routing with middleware.                           | Expressive HTTP layer.                 |
| **HttpKernel**       | Binds server to routes & middleware stack.                   | Separation of transport vs. app code.  |
| **ConfigRepository** | Read structured config (env, files).                         | 12‑factor friendly.                    |

---

## Minimal examples

### Container

```dart
final c = Container.root();

c.singleton<Logger>(() => ConsoleLogger());
c.factory<Clock>(() => SystemClock.now());

final logger = c.make<Logger>();
logger.info('container ready');
```

### Provider

```dart
class RouterProvider extends Provider {
  final void Function(Router) configure;
  RouterProvider({required this.configure});

  @override
  void register(ServiceContainer c) {
    final router = Router();
    configure(router);
    c.bind<Router>(router);
  }
}
```

### Routing & middleware

```dart
void registerRoutes(Router r) {
  r.use((req, next) { /* global middleware */ next(); });

  r.get('/health', (req) => req.json({'ok': true}));

  r.group('/v1', (api) {
    api.get('/users/:id', (req) async {
      final id = RouteParams.get<int>('id');
      return req.json({'id': id});
    });
  });
}
```

---
## Configuration

Archery prefers **code over convention**, but supports config repositories so you can do:

```dart
final cfg = container.make<ConfigRepository>();
final port = cfg.get<int>('server.port', defaultValue: 5501);
```

Bring your own loader (env, JSON/YAML, secrets manager). A default file/env loader is on the roadmap.

---

For HTTP tests, spin up the `HttpKernel` on an ephemeral port and call it with `HttpClient`.

---

## Performance notes

* Built on `dart:io`.
* Minimal allocations in the hot path.
* Route matching designed for predictable performance.
* Container avoids reflection; favors generics and factories.

---

## Roadmap

* [x] Service Container polish (disposal hooks, readiness)
* [x] Provider lifecycle ergonomics
* [x] Router & middleware (typed params, groups, prefixes)
* [x] HTTP Kernel (static files, error handling)
* [x] Template engine (Stitch)
* [x] ORM (Archer)
* [ ] CLI (`archery new <app>`)

---


---

## License

BSD © WebArchery
