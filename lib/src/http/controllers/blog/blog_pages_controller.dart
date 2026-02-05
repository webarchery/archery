import 'package:archery/archery/archery.dart';

final List<Map<String, dynamic>> blogPostsSeed = [
  {
    "id": 1,
    "title": "Welcome to Archery",
    "slug": "welcome-to-archery",
    "excerpt": "An introduction to the Archery framework — pragmatic, fast, and built with Dart.",
    "content": """
Archery is a modern web framework for Dart, designed to help developers build expressive and high-performance web apps with ease.

In this post, we’ll explore the philosophy behind Archery, its design principles, and what makes it different from other frameworks.
    """,
    "author": "King Archer",
    "category": "Framework",
    "published_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 1)),
    "created_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 1)),
    "updated_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 1)),
  },
  {
    "id": 2,
    "title": "Dependency Injection Simplified",
    "slug": "dependency-injection-simplified",
    "excerpt": "A look at Archery’s Service Container and how it brings clean dependency management to your Dart apps.",
    "content": """
Archery’s Service Container is the heart of the framework’s architecture. It manages object lifecycles, dependencies, and service resolution.

With features like factories, singletons, and scoped containers, you can achieve Laravel-like elegance in Dart.
    """,
    "author": "King Archer",
    "category": "Architecture",
    "published_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 3)),
    "created_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 3)),
    "updated_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 3)),
  },
  {
    "id": 3,
    "title": "Routing with Archery",
    "slug": "routing-with-archery",
    "excerpt": "Learn how Archery’s Router handles dynamic routes, middleware, and controllers efficiently.",
    "content": """
The Router in Archery allows expressive route definitions, including dynamic parameters and middleware chaining.

You can define routes declaratively, and soon, even use typed dynamic parameters for type-safe request handling.
    """,
    "author": "King Archer",
    "category": "HTTP",
    "published_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 5)),
    "created_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 5)),
    "updated_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 5)),
  },
  {
    "id": 4,
    "title": "Understanding Middleware",
    "slug": "understanding-middleware",
    "excerpt": "Middleware provides a way to wrap requests in logic before they reach the route handler.",
    "content": """
In Archery, middleware functions can intercept and modify requests or responses.

This design allows for authentication, logging, and caching layers that are cleanly separated from business logic.
    """,
    "author": "King Archer",
    "category": "HTTP",
    "published_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 7)),
    "created_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 7)),
    "updated_at": DateFormat('EEEE, MMMM d, yyyy').format(DateTime(2025, 10, 7)),
  },
];

class BlogPagesController {
  static Future<dynamic> index(HttpRequest request) async {
    return request.view("blog.index", {'posts': blogPostsSeed});
  }

  static Future<dynamic> show<T>(HttpRequest request) async {
    final slug = RouteParams.get<String>('slug');
    try {
      final post = blogPostsSeed.firstWhere((post) => post['slug'] == slug);
      return request.view('blog.show', {'post': post});
    } catch (e) {
      return request.notFound();
    }
  }
}
