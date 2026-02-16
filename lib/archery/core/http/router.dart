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

/// Signature for HTTP route handlers.
///
/// Receives an [HttpRequest] and returns a [Future<dynamic>].
typedef Handler = Future<dynamic> Function(HttpRequest request);

/// Signature for HTTP middleware functions.
///
/// Receives an [HttpRequest] and a [next] callback to continue the chain.
typedef HttpMiddleware = Future<dynamic> Function(HttpRequest request, Future<void> Function() next);

/// HTTP methods supported by the router.
enum HttpMethod {
  /// GET request
  get,

  /// POST request
  post,

  /// PUT request
  put,

  /// DELETE request
  delete,

  /// PATCH request
  patch,
}

/// Core HTTP router with support for:
/// - Static and dynamic routes
/// - Parameterized routes with type coercion (`/users/{id:int}`
/// - Nested route groups with shared middleware/prefixes
/// - Middleware pipelines
/// - Zone-based parameter injection
///
/// **Dynamic Route Syntax:**
/// ```dart
/// router.get('/users/{id:int}/posts/{slug:string}', handler);
/// ```
///
/// **Supported Parameter Types:** `int`, `double`, `uuid`, `string`
base class Router {
  /// Public view of registered static routes (for debugging).
  Map<HttpMethod, Map<String, Handler>> get routes => _routes;

  final Map<HttpMethod, Map<String, Handler>> _routes = {};
  final Map<HttpMethod, Map<String, List<HttpMiddleware>>> _middlewareMap = {};

  /// Dynamic routes: method → list of compiled routes.
  final Map<HttpMethod, List<_CompiledRoute>> _dynamicRoutes = {};

  /// Stack of current route prefixes (for groups).
  final List<String> _prefixStack = [''];

  /// Stack of current middleware (for groups).
  final List<List<HttpMiddleware>> _mwStack = [const []];

  /// Defines a route group with shared [prefix] and [middleware].
  ///
  /// All routes defined inside [routes] callback inherit the prefix and middleware.
  ///
  /// Example:
  /// ```dart
  /// router.group(prefix: '/api/v1', middleware: [authMw], routes: () {
  ///   router.get('/users', handler);
  ///   // Becomes: GET /api/v1/users with authMw
  /// });
  /// ```
  void group({String prefix = '', List<HttpMiddleware> middleware = const [], required void Function() routes}) {
    _prefixStack.add(_join(_currentPrefix, _normalizePrefix(prefix)));
    _mwStack.add([..._currentMiddleware, ...middleware]);

    try {
      routes();
    } finally {
      _prefixStack.removeLast();
      _mwStack.removeLast();
    }
  }

  /// Registers a GET route.
  void get(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) => _add(HttpMethod.get, path, handler, middleware: middleware);

  /// Registers a POST route.
  void post(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) => _add(HttpMethod.post, path, handler, middleware: middleware);

  /// Registers a PUT route.
  void put(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) => _add(HttpMethod.put, path, handler, middleware: middleware);

  /// Registers a PATCH route.
  void patch(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) => _add(HttpMethod.patch, path, handler, middleware: middleware);

  /// Registers a DELETE route.
  void delete(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) => _add(HttpMethod.delete, path, handler, middleware: middleware);

  /// Registers a pre-defined [Route] object.
  void addRoute(Route r) => _add(r.method, r.path, r.handler, middleware: r.middleware);

  /// Internal: Adds a route with current group context applied.
  void _add(HttpMethod m, String path, Handler handler, {List<HttpMiddleware> middleware = const []}) {
    final fullPath = _join(_currentPrefix, _normalizePath(path));
    final combinedMw = [..._currentMiddleware, ...middleware];

    final route = Route(method: m, path: fullPath, middleware: combinedMw, handler: handler);
    _register(route);
  }

  /// Internal: Registers a route (static or dynamic).
  void _register(Route route) {
    if (_looksDynamic(route.path)) {
      final cr = _compile(route);
      _dynamicRoutes.putIfAbsent(route.method, () => []).add(cr);
    } else {
      _routes.putIfAbsent(route.method, () => {})[route.path] = route.handler;
      // Store middleware per method+path
      _middlewareMap.putIfAbsent(route.method, () => {})[route.path] = route.middleware;
    }
  }

  /// Dispatches an [HttpRequest] to the matching route.
  ///
  /// **Matching Priority:**
  /// 1. Exact static routes
  /// 2. Dynamic routes (regex + type coercion)
  /// 3. 404 Not Found
  ///
  /// Parameters are injected into [Zone] and accessible via [RouteParams].
  Future<void> dispatch(HttpRequest request) async {

    final spoofMethod = request.uri.queryParameters['_method'];
    HttpMethod method = _parseMethod(request.method);

    if (spoofMethod != null) {
      method = _parseMethod(spoofMethod);
    }

    final path = _normalize(request.uri.path);

    // 1. Static route lookup (fastest)
    final handler = _routes[method]?[path];
    // Get middleware for this specific method+path combination
    final middleware = _middlewareMap[method]?[path] ?? const [];

    if (handler != null) {
      await _runMiddleware(request, middleware, 0, () async => await handler(request));
      return;
    }

    // 2. Dynamic route matching
    final compiled = _dynamicRoutes[method] ?? const [];
    for (final cr in compiled) {
      final match = cr.regex.firstMatch(path);
      if (match == null) continue;

      // Extract and coerce parameters
      final params = <String, dynamic>{};
      var valid = true;

      for (var i = 0; i < cr.paramNames.length; i++) {
        final raw = match.group(i + 1)!;
        final typeName = cr.paramTypes[i];
        final coerced = _coerce(raw, typeName);

        if (coerced is _Coerce && coerced.value == null) {
          valid = false;
          break;
        }
        params[cr.paramNames[i]] = coerced is _Coerce ? coerced.value! : coerced;
      }

      if (!valid) continue;

      // Execute with params in Zone
      runZoned(() async => await _runMiddleware(request, cr.middleware, 0, () => cr.handler(request)), zoneValues: RouteParams._zoneValues(params));

      return;
    }

    // 3. Not found
    await request.notFound();
  }

  /// Current prefix from group stack.
  String get _currentPrefix => _prefixStack.last;

  /// Current middleware from group stack.
  List<HttpMiddleware> get _currentMiddleware => _mwStack.last;

  /// Normalizes a group prefix (ensures leading `/`, trims trailing `/`).
  String _normalizePrefix(String p) {
    if (p.isEmpty || p == '/') return '';
    if (!p.startsWith('/')) p = '/$p';
    if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
    return p;
  }

  /// Normalizes a route path (ensures leading `/`).
  String _normalizePath(String p) {
    if (p.isEmpty || p == '/') return '/';
    if (!p.startsWith('/')) p = '/$p';
    return p;
  }

  /// Joins two path segments intelligently.
  String _join(String a, String b) {
    if (a.isEmpty) return b;
    if (b == '/') return a.isEmpty ? '/' : a;
    return b == '' ? a : (a.endsWith('/') ? '$a${b.substring(1)}' : '$a$b');
  }

  /// Detects dynamic routes by presence of `{...}` placeholders.
  bool _looksDynamic(String p) => p.contains('{') && p.contains('}');

  /// Executes middleware chain recursively.
  ///
  /// Calls [onComplete] after all middleware finishes.
  Future<void> _runMiddleware(HttpRequest req, List<HttpMiddleware> list, int index, Future<void> Function() onComplete) async {
    if (index < list.length) {
      await list[index](req, () => _runMiddleware(req, list, index + 1, onComplete));
    } else {
      await onComplete();
    }
  }

  /// Parses HTTP method string to [HttpMethod] enum.
  HttpMethod _parseMethod(String method) => HttpMethod.values.firstWhere((m) => m.name.toUpperCase() == method.toUpperCase(), orElse: () => HttpMethod.get);

  /// Normalizes request path (trims trailing `/`).
  String _normalize(String p) {
    if (p.isEmpty) return '/';
    if (p.length > 1 && p.endsWith('/')) return p.substring(0, p.length - 1);
    return p;
  }

  /// Compiles a dynamic route into regex + param metadata.
  ///
  /// Example: `/users/{id:int}/posts/{slug:string}`
  /// → `^/users/([0-9]+)/posts/([^/]+)$`
  _CompiledRoute _compile(Route r) {
    final segs = r.path.split('/').where((s) => s.isNotEmpty).toList();
    final paramNames = <String>[];
    final paramTypes = <String>[];
    final regexParts = <String>['^'];

    final token = RegExp(r'^\{([A-Za-z_]\w*):([A-Za-z_]\w*)\}$');

    for (final s in segs) {
      if (token.hasMatch(s)) {
        final m = token.firstMatch(s)!;
        final name = m.group(1)!;
        final typeName = m.group(2)!.toLowerCase();

        paramNames.add(name);
        paramTypes.add(typeName);
        regexParts.add('/');
        regexParts.add(_typeToGroup(typeName));
      } else {
        regexParts.add('/');
        regexParts.add(RegExp.escape(s));
      }
    }

    if (segs.isEmpty) {
      regexParts.add(RegExp.escape('/'));
    }
    regexParts.add(r'$');

    return _CompiledRoute(method: r.method, regex: RegExp(regexParts.join()), paramNames: paramNames, paramTypes: paramTypes, middleware: r.middleware, handler: r.handler);
  }

  /// Converts parameter type to regex capture group.
  String _typeToGroup(String typeName) {
    switch (typeName) {
      case 'int':
        return r'([0-9]+)';
      case 'double':
        return r'([0-9]+(?:\.[0-9]+)?)';
      case 'uuid':
        return r'([0-9a-fA-F-]{36})';
      case 'string':
      default:
        return r'([^/]+)';
    }
  }

  /// Lists all registered routes (static paths + dynamic regex patterns).
  Map<HttpMethod, List<String>> listRoutes() => {
    for (final m in HttpMethod.values) m: [...(_routes[m]?.keys ?? const []), ...(_dynamicRoutes[m]?.map((cr) => cr.regex.pattern) ?? const [])],
  };
}

/// Basic route definition structure.
base class Route {
  /// HTTP method.
  HttpMethod method;

  /// Path pattern (static or dynamic with `{param:type}`).
  String path;

  /// Middleware chain.
  List<HttpMiddleware> middleware;

  /// Route handler.
  Handler handler;

  /// Creates a new route definition.
  Route({required this.method, required this.path, this.middleware = const [], required this.handler});
}

/// Utility class for accessing route parameters in handlers and middleware.
///
/// Parameters are available via [Zone] values during request dispatch.
/// Supports type-safe retrieval with generics.
base class RouteParams {
  /// Private zone key for storing route parameters.
  static final Object _key = Object();

  /// Returns all route parameters as a [Map].
  ///
  /// Returns empty map if no parameters are available.
  static Map<String, dynamic> all() => (Zone.current[_key] as Map<String, dynamic>?) ?? const {};

  /// Retrieves a typed route parameter by [name].
  ///
  /// Returns `null` if parameter doesn't exist or type doesn't match.
  ///
  /// Example:
  /// ```dart
  /// final id = RouteParams.get<int>('id'); // 123
  /// final slug = RouteParams.get<String>('slug'); // 'my-post'
  /// ```
  static T? get<T>(String name) => all()[name] as T?;

  /// Creates zone values containing the route [params].
  static Map<Object?, Object?> _zoneValues(Map<String, dynamic> params) => {_key: params};
}

/// Internal representation of a compiled dynamic route.
///
/// Contains regex pattern, parameter metadata, and execution pipeline.
base class _CompiledRoute {
  const _CompiledRoute({required this.method, required this.regex, required this.paramNames, required this.paramTypes, required this.middleware, required this.handler});

  /// HTTP method this route matches.
  final HttpMethod method;

  /// Regex pattern for path matching (with capture groups for params).
  final RegExp regex;

  /// Names of captured parameters (in regex group order).
  final List<String> paramNames;

  /// Expected types for each parameter (e.g., 'int', 'string').
  final List<String> paramTypes;

  /// Middleware chain for this route.
  final List<HttpMiddleware> middleware;

  /// Handler to execute after middleware.
  final Handler handler;
}

/// Internal wrapper for type coercion results.
base class _Coerce {
  const _Coerce(this.value);

  /// Successfully coerced value.
  final dynamic value;

  /// Static sentinel for coercion failure.
  static const fail = _Coerce(null);
}

/// Coerces a raw string parameter to the specified [typeName].
///
/// Returns [_Coerce] with value on success, [_Coerce.fail] on failure.
dynamic _coerce(String raw, String typeName) {
  switch (typeName) {
    case 'int':
      final v = int.tryParse(raw);
      return v == null ? _Coerce.fail : _Coerce(v);
    case 'double':
      final v = double.tryParse(raw);
      return v == null ? _Coerce.fail : _Coerce(v);
    case 'uuid':
      final ok = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(raw);
      return ok ? _Coerce(raw) : _Coerce.fail;
    case 'string':
    default:
      return _Coerce(raw);
  }
}
