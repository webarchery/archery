
---

# Archery - A Full-Stack Web Framework for Dart

Laravel-inspired developer flow. Dart-native performance.  
A readable, minimal, batteries-included backend framework for **Dart 3**.

---

## Why Archery
Archery reimagines backend development in Dart with a small set of predictable building blocks:

- Predictable – explicit, type‑safe APIs. No hidden magic.
- Minimal – keep the surface area tiny; build only what’s needed.
- Composable – IoC container + providers let features snap together.
- Fast – built directly on dart:io for zero overhead

---

## Features

- **IoC Container** - simple, predictable dependency resolution
- **HTTP Kernel & Router** - controllers, middleware, groups, typed params
- **HTML Templating Engine** - Blade-style includes & layouts
- **ORM (JSON + SQLite)** - migrations, models, CRUD helpers
- **Auth System** - login, register, sessions, middleware
- **Static File Server** - safe MIME mapping, caching, SPA fallback
- **Config Loader** - JSON configs with dot-notation access
- **Example App** - routes, controllers, auth views, blog, todos

Archery aims to stay small, explicit, and easy to read, without sacrificing the comforts of a real framework.

---

## Project Structure

```
lib/
    archery/                            # Framework core
        core/
            application.dart            # App lifecycle & provider registry
            container.dart              # ServiceContainer (DI)
            config.dart                 # JSON config loader
            kernel.dart                 # HTTP kernel
            provider.dart               # Provider base class
            template_engine.dart        # HTML templating engine
            static_files_server.dart
    
            http/
              router.dart               # Routes, groups, params, middleware
              body_parser.dart          # Form-data, URL-encoded, JSON, file uploads
              extensions.dart           # request.view(), request.json(), redirects

            orm/
              model.dart                # Base Model API
              json_file_model.dart
              sqlite_model.dart
              hasher.dart

            auth/
              auth_session.dart         # Sessions, login/logout, auth middleware
              
    src/                                # project source code
        config/                         # app.json, server.json
        database/                       # User model + migrations
        http/
            routes/                     # web.dart, api.dart
            controllers/
            views/                      # HTML templates
            public/                     # css/js/img
        apps/
            todos.dart                  # Todo model + routes

```



## Getting Started

### 1. Install dependencies

```bash
git clone https://github.com/webarchery/archery
cd archery
dart pub get
````

### 2. Run the server

```bash
dart run bin/server.dart
```

Default server config lives in `lib/src/config/server.json`:

```json
{
  "domain": "localhost",
  "port": 5501,
  "compress": true
}
```

Visit your app at:

**localhost port 5501**

### 3. (Optional) Enable live reload
Install dartmon_cli for reloading server

```bash
dart pub global activate dartmon_cli

dartmon run bin/server.dart

```
BrowserSync watches HTML/CSS/JS/Dart files.
```bash
npm install
npm run start
```

---

## Core Concepts

### App & Container

`App` bootstraps the framework and exposes a DI container:

```dart
final app = App();
await app.boot();
```

The container supports:

* `bind` (transient)
* `singleton`
* `bindInstance`
* scoped containers
* disposal callbacks

### Routing

* GET/POST/PUT/PATCH/DELETE
* Route groups and middleware
* Typed params: `{id:int}`, `{slug:string}`
* `RouteParams.get<T>()` for safe access

```dart
router.get('/blog/{slug:string}', BlogPagesController.show);
```

### Templates

Blade-style templates in `lib/src/http/views`:

```dart
@include('includes._main-header')
<h1>{{ title }}</h1>
@include('includes._main-footer')
```

Render in controllers:

```dart
return request.view('welcome', {'title': 'Hello'});
```

### Request Helpers

* `request.input('field')`
* `request.file('avatar')`
* `request.files()`
* `request.json(data)`
* `request.view(template, data)`
* `request.redirectToLogin()` / `redirectBack()`

Handles:

* JSON
* URL-encoded forms
* Multipart forms + file uploads (`UploadedFile`)

### ORM

Four backends:

* **JsonFileModel** — fast prototyping
* **SQLiteModel**   — SQLite persistence (via `sqflite_common_ffi`)
* **PostgresModel** — Postgres persistence (via `postgres`)
* **S3JsonModel**   — S3 persistence (via `archery_s3_client`)

Models implement:

```dart
static fromJson(Map json)
toJson(),    // for public api fields
toMetaJson() // for private db fields
Map<String, String> columnDefinitions
```

Migrations are plain Dart functions (`lib/src/database/migrations.dart`).

### Auth

Located in `archery/auth/auth_session.dart`:

* Cookie-based sessions
* 1-hour expiration
* `Auth.user(request)` returns  User?
* `Auth.check(request)` returns bool
* `Auth.middleware` / `Guest.middleware`
* Auth routes + views included:

    * `/login`
    * `/register`
    * `/logout`
    * `/user/profile`
    * `/user/dashboard`

---

## Example Features Included

* Auth pages and dashboard
* Welcome screen
* Asset pipeline via `public/`

These examples double as documentation for how to structure your own app.

---

## Roadmap

* CLI: `archery new <app>`
* Mailer
* Queue workers

---

## License

**BSD-3-Clause**
See LICENSE file for details.
