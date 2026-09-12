import 'package:archery/archery/archery.dart';
import 'package:test/test.dart';

// --- Mocks ---

final class MockTemplateEngine extends TemplateEngine {
  MockTemplateEngine() : super(viewsDirectory: 'mock', publicDirectory: 'mock');

  @override
  Future<String> render(
    String templateName, [
    Map<String, dynamic>? data,
  ]) async {
    return 'Rendered: $templateName';
  }
}

class MockHttpHeaders implements HttpHeaders {
  final Map<String, dynamic> _headers = {};

  @override
  ContentType? contentType;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = value;
  }

  @override
  String? value(String name) => _headers[name]?.toString();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpResponse implements HttpResponse {
  final MockHttpHeaders _headers = MockHttpHeaders();
  @override
  int statusCode = HttpStatus.ok;
  final StringBuffer _buffer = StringBuffer();
  final List<Cookie> _cookies = [];
  bool _closed = false;

  String get output => _buffer.toString();
  bool get isClosed => _closed;

  @override
  HttpHeaders get headers => _headers;

  @override
  List<Cookie> get cookies => _cookies;

  @override
  void write(Object? object) {
    _buffer.write(object);
  }

  @override
  Future close() async {
    _closed = true;
    return this;
  }

  @override
  Future redirect(
    Uri location, {
    int status = HttpStatus.movedTemporarily,
  }) async {
    statusCode = status;
    headers.set('Location', location.toString());
    close();
    return this;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpRequest implements HttpRequest {
  final Uri _uri;
  final String _method;
  final MockHttpResponse _response = MockHttpResponse();
  final List<Cookie> _cookies = [];

  MockHttpRequest(String method, String path)
    : _method = method,
      _uri = Uri.parse('http://localhost$path');

  @override
  Uri get uri => _uri;

  @override
  String get method => _method;

  @override
  HttpResponse get response => _response;

  @override
  List<Cookie> get cookies => _cookies;

  MockHttpResponse get mockResponse => _response;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- Tests ---

void main() {
  late Router router;

  setUp(() async {
    await App().container.dispose();

    // Bind Mock Template Engine
    App().container.bindInstance<TemplateEngine>(MockTemplateEngine());

    // Create and Bind Config
    final tempDir = Directory.systemTemp.createTempSync('archery_test');
    File('${tempDir.path}/app.json').writeAsStringSync('{"debug": false}');
    final config = await AppConfig.create(path: tempDir.path);
    App().container.bindInstance<AppConfig>(config);

    router = Router();
    // Bind Router as well since some internal checks might look it up
    App().container.bindInstance<Router>(router);

    // Bind UUID
    // App().container.bindInstance<Uuid>(Uuid());
  });

  group('Router Method Matching', () {
    test('matches GET route', () async {
      var called = false;
      router.get('/test', (req) async {
        called = true;
        return req.text('OK');
      });

      final req = MockHttpRequest('GET', '/test');
      await router.dispatch(req);

      expect(called, isTrue);
      expect(req.mockResponse.statusCode, HttpStatus.ok);
    });

    test('matches POST route', () async {
      var called = false;
      router.post('/store', (req) async {
        called = true;
        return req.text('Stored');
      });

      final req = MockHttpRequest('POST', '/store');
      await router.dispatch(req);

      expect(called, isTrue);
    });

    test('does not match wrong method', () async {
      router.get('/only-get', (req) async => req.text('OK'));

      final req = MockHttpRequest('POST', '/only-get');
      await router.dispatch(req);

      // Should be 404/Not Found because method doesn't match
      // The router treats method mismatch effectively as route not found for that method
      expect(req.mockResponse.statusCode, HttpStatus.notFound);
      expect(req.mockResponse.output, contains('Rendered: errors.404'));
    });
  });

  group('Router Parameters', () {
    test('matches parameterized route {id:int}', () async {
      int? capturedId;
      router.get('/users/{id:int}', (req) async {
        capturedId = RouteParams.get<int>('id');
        return req.text('User $capturedId');
      });

      final req = MockHttpRequest('GET', '/users/42');
      await router.dispatch(req);

      expect(capturedId, equals(42));
      expect(req.mockResponse.statusCode, HttpStatus.ok);
    });

    test('matches parameterized route {slug:string}', () async {
      String? capturedSlug;
      router.get('/posts/{slug:string}', (req) async {
        capturedSlug = RouteParams.get<String>('slug');
        return req.text('Post $capturedSlug');
      });

      final req = MockHttpRequest('GET', '/posts/hello-world');
      await router.dispatch(req);

      expect(capturedSlug, equals('hello-world'));
    });

    test('fails matching if type constraint fails', () async {
      router.get('/users/{id:int}', (req) async => req.text('User'));

      final req = MockHttpRequest('GET', '/users/not-an-int');
      await router.dispatch(req);

      expect(req.mockResponse.statusCode, HttpStatus.notFound);
    });
  });

  group('Router Grouping', () {
    test('applies prefix to routes', () async {
      var called = false;
      router.group(
        prefix: '/api/v1',
        routes: () {
          router.get('/users', (req) async {
            called = true;
            return req.text('API Users');
          });
        },
      );

      final req = MockHttpRequest('GET', '/api/v1/users');
      await router.dispatch(req);

      expect(called, isTrue);
    });

    test('applies middleware to group', () async {
      final log = <String>[];

      Future<dynamic> mw(HttpRequest req, Future<void> Function() next) async {
        log.add('middleware');
        await next();
      }

      router.group(
        middleware: [mw],
        routes: () {
          router.get('/protected', (req) async {
            log.add('handler');
            return req.text('Protected');
          });
        },
      );

      final req = MockHttpRequest('GET', '/protected');
      await router.dispatch(req);

      expect(log, equals(['middleware', 'handler']));
    });

    test('nested groups combine prefixes', () async {
      var called = false;
      router.group(
        prefix: '/api',
        routes: () {
          router.group(
            prefix: '/v2',
            routes: () {
              router.get('/data', (req) async {
                called = true;
                return req.text('Data');
              });
            },
          );
        },
      );

      final req = MockHttpRequest('GET', '/api/v2/data');
      await router.dispatch(req);

      expect(called, isTrue);
    });
  });

  group('Middleware Order', () {
    test('executes middleware in order', () async {
      final log = <String>[];

      Future<dynamic> mw1(HttpRequest req, Future<void> Function() next) async {
        log.add('mw1 start');
        await next();
        log.add('mw1 end');
      }

      Future<dynamic> mw2(HttpRequest req, Future<void> Function() next) async {
        log.add('mw2 start');
        await next();
        log.add('mw2 end');
      }

      router.get('/ordered', (req) async {
        log.add('handler');
        return req.text('OK');
      }, middleware: [mw1, mw2]);

      final req = MockHttpRequest('GET', '/ordered');
      await router.dispatch(req);

      expect(
        log,
        equals([
          'mw1 start',
          'mw2 start',
          'handler',
          'mw2 end', // Middleware continue logic is purely recursive callback based
          'mw1 end',
        ]),
      );
    });
  });

  group('404/405 Behavior', () {
    test('returns 404 for unknown route', () async {
      final req = MockHttpRequest('GET', '/unknown/path');
      await router.dispatch(req);

      expect(req.mockResponse.statusCode, HttpStatus.notFound);
      expect(req.mockResponse.output, contains('Rendered: errors.404'));
    });

    test('returns 404 (not 405 explicitly) for wrong method', () async {
      router.post('/submit', (req) async => req.text('OK'));

      final req = MockHttpRequest('GET', '/submit');
      await router.dispatch(req);

      // Current implementation does not distinguish 405, it just falls through to 404
      expect(req.mockResponse.statusCode, HttpStatus.notFound);
    });
  });
}
