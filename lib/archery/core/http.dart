import 'package:archery/archery/archery.dart';


typedef Handler = Future<dynamic> Function(HttpRequest request);
typedef HttpMiddleware = Future<dynamic> Function(HttpRequest request, void Function() next);

enum HttpMethod { get, post, put, delete, patch }

class RouteParams {
  static final Object _key = Object();

  static Map<String, dynamic> all() => (Zone.current[_key] as Map<String, dynamic>?) ?? const {};

  static T? get<T>(String name) => all()[name] as T?;

  static Map<Object?, Object?> _zoneValues(Map<String, dynamic> params) => {_key: params};
}

class _CompiledRoute {
  _CompiledRoute({
    required this.method,
    required this.regex,
    required this.paramNames,
    required this.paramTypes,
    required this.middleware,
    required this.handler,
  });

  final HttpMethod method;
  final RegExp regex;
  final List<String> paramNames;
  final List<String> paramTypes;
  final List<HttpMiddleware> middleware;
  final Handler handler;
}


class Route {
  HttpMethod method;
  String path;
  List<HttpMiddleware> middleware;
  Handler handler;

  Route({
    required this.method,
    required this.path,
    this.middleware = const [],
    required this.handler,
  });
}

class Router {



  Map<HttpMethod, Map<String, Handler>> get routes => _routes;
  final Map<HttpMethod, Map<String, Handler>> _routes = {};
  final Map<String, List<HttpMiddleware>> _middlewareMap = {};
  final Map<HttpMethod, List<_CompiledRoute>> _dynamicRoutes = {};

  final List<String> _prefixStack = [''];
  final List<List<HttpMiddleware>> _mwStack = [const []];


  // route group with a builder closure
  void group({
    String prefix = '',
    List<HttpMiddleware> middleware = const [],
    required void Function() routes,
  }) {
    // push scope
    _prefixStack.add(_join(_currentPrefix, _normalizePrefix(prefix)));
    _mwStack.add([..._currentMiddleware, ...middleware]);

    try {
      routes();
    } finally {
      // pop scope
      _prefixStack.removeLast();
      _mwStack.removeLast();
    }
  }

  // verbs
  void get(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) =>
      _add(HttpMethod.get, path, handler, middleware: middleware);

  void post(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) =>
      _add(HttpMethod.post, path, handler, middleware: middleware);

  void put(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) =>
      _add(HttpMethod.put, path, handler, middleware: middleware);

  void patch(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) =>
      _add(HttpMethod.patch, path, handler, middleware: middleware);

  void delete(String path, Handler handler, {List<HttpMiddleware> middleware = const []}) =>
      _add(HttpMethod.delete, path, handler, middleware: middleware);

  void addRoute(Route r) => _add(r.method, r.path, r.handler, middleware: r.middleware);

  void _add(HttpMethod m, String path, Handler handler, {List<HttpMiddleware> middleware = const []}) {
    final fullPath = _join(_currentPrefix, _normalizePath(path));
    final combinedMw = [..._currentMiddleware, ...middleware];

    final route = Route(method: m, path: fullPath, middleware: combinedMw, handler: handler);
    _register(route);
  }

  void _register(Route route) {
    // Detect dynamic
    if (_looksDynamic(route.path)) {
      final cr = _compile(route);
      _dynamicRoutes.putIfAbsent(route.method, () => []).add(cr);
    } else {
      _routes.putIfAbsent(route.method, () => {})[route.path] = route.handler;
      _middlewareMap[route.path] = route.middleware;
    }
  }

  // ===== Dispatch (keep your current implementation) =====

  void dispatch(HttpRequest request) async {

    final method = _parseMethod(request.method);
    final path = _normalize(request.uri.path);

    // 1) Try static first
    final handler = _routes[method]?[path];
    final middleware = _middlewareMap[path] ?? [];

    if (handler != null) {
      _runMiddleware(request, middleware, 0, () async => await handler(request));
      return;
    }

    // 2) Try dynamic
    final compiled = _dynamicRoutes[method] ?? const [];
    for (final cr in compiled) {
      final m = cr.regex.firstMatch(path);
      if (m == null) continue;

      // Coerce captured groups by type
      final params = <String, dynamic>{};
      var ok = true;

      for (var i = 0; i < cr.paramNames.length; i++) {
        final raw = m.group(i + 1)!;
        final typeName = cr.paramTypes[i];
        final coerced = _coerce(raw, typeName);
        if (coerced == _Coerce.fail) {
          ok = false;
          break;
        }
        params[cr.paramNames[i]] = coerced is _Coerce ? coerced.value : coerced;
      }

      if (!ok) continue; // wrong type; keep looking

      // Run the pipeline with params available via RouteParams.get<T>()
      runZoned(
            () => _runMiddleware(
          request,
          cr.middleware,
          0,
              () => cr.handler(request),
        ),
        zoneValues: RouteParams._zoneValues(params),
      );
      return;
    }

    // 3) Not found
    request.notFound();
  }

  String get _currentPrefix => _prefixStack.last;
  List<HttpMiddleware> get _currentMiddleware => _mwStack.last;

  String _normalizePrefix(String p) {
    if (p.isEmpty || p == '/') return '';
    if (!p.startsWith('/')) p = '/$p';
    if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
    return p;
  }
  String _normalizePath(String p) {
    if (p.isEmpty || p == '/') return '/';
    if (!p.startsWith('/')) p = '/$p';
    return p;
  }
  String _join(String a, String b) {
    if (a.isEmpty) return b;
    if (b == '/') return a.isEmpty ? '/' : a;
    return b == '' ? a : (a.endsWith('/') ? '$a${b.substring(1)}' : '$a$b');
  }

  bool _looksDynamic(String p) => p.contains('{') && p.contains('}');



  void _runMiddleware(
      HttpRequest req,
      List<HttpMiddleware> list,
      int index,
      void Function() onComplete,
      ) {
    if (index < list.length) {
      list[index](req, () => _runMiddleware(req, list, index + 1, onComplete));
    } else {
      onComplete();
    }
  }

  HttpMethod _parseMethod(String method) => HttpMethod.values.firstWhere(
        (m) => m.name.toUpperCase() == method.toUpperCase(),
    orElse: () => HttpMethod.get,
  );

  String _normalize(String p) {
    if (p.isEmpty) return '/';
    if (p.length > 1 && p.endsWith('/')) return p.substring(0, p.length - 1);
    return p;
  }


  // Build ^/...$ regex + param lists from: /users/{id:int}/posts/{slug:string}
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
        regexParts.add(_typeToGroup(typeName)); // capture group
      } else {
        regexParts.add('/');
        regexParts.add(RegExp.escape(s));
      }
    }

    if (segs.isEmpty) {
      regexParts.add(RegExp.escape('/')); // root '/'
    }
    regexParts.add(r'$');

    return _CompiledRoute(
      method: r.method,
      regex: RegExp(regexParts.join()),
      paramNames: paramNames,
      paramTypes: paramTypes,
      middleware: r.middleware,
      handler: r.handler,
    );
  }

  String _typeToGroup(String typeName) {
    switch (typeName) {
      case 'int':
        return r'([0-9]+)';
      case 'double':
        return r'([0-9]+(?:\.[0-9]+)?)';
      case 'uuid':
      // simple UUID v4ish (36 chars with hyphens) — adjust as needed
        return r'([0-9a-fA-F-]{36})';
      case 'string':
      default:
        return r'([^/]+)';
    }
  }

  Map<HttpMethod, List<String>> listRoutes() => {
    for (final m in HttpMethod.values)
      m: [
        ...(_routes[m]?.keys ?? const []),
        ...(_dynamicRoutes[m]?.map((cr) => cr.regex.pattern) ?? const []),
      ],
  };
}

class _Coerce {
  _Coerce(this.value);
  final dynamic value;
  static final fail = _Coerce(null);
}

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