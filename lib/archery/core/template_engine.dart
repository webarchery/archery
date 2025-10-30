

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

/// Exception thrown by [TemplateEngine] during rendering.
///
/// Covers:
/// - Template file not found
/// - Variable not found in data
/// - Invalid syntax (future)
class TemplateEngineException implements Exception {
  /// Error message.
  String? message;
  /// Generic constructor.
  TemplateEngineException(this.message);
  /// Thrown when a variable is referenced but not present in data.
  TemplateEngineException.variableNotFound(String? errorMessage) : message = errorMessage;
  /// Thrown when a template file cannot be located.
  TemplateEngineException.templateNotFound(String? errorMessage) : message = errorMessage;

  @override
  String toString() {
    return "Template Error: $message";
  }
}

/// Lightweight, file-based template engine with:
/// - Dot-notation template paths (`admin.users.index`)
/// - Layouts (`@layout('base')`)
/// - Sections (`@section('title')...@endsection`)
/// - Includes (`@include('partials.nav', {'active': 'home'})`)
/// - Loops (`@foreach(items as item)`)
/// - Conditionals (`@if(user.isAdmin)`)
/// - Safe & raw interpolation (`{{ name }}`, `{!! html !!}`)
/// - Caching
///
/// **Template Path Resolution:**
/// ```text
/// viewsDirectory + templateName.replace('.', '/') + '.html'
/// ```
/// Example: `users.profile` → `lib/src/http/views/users/profile.html`
class TemplateEngine {
  /// Directory containing `.html` view templates.
  final String viewsDirectory;
  /// Public assets directory (not used directly by engine).
  final String publicDirectory;
  /// In-memory cache of compiled template content.
  final Map<String, String> _cache = {};

  /// Creates a new template engine.
  ///
  /// - [viewsDirectory]: Required. Base path for templates.
  /// - [publicDirectory]: Required. Not used by engine (for static assets).
  TemplateEngine({required this.viewsDirectory, required this.publicDirectory});

  /// Renders a [templateName] with optional [data].
  ///
  /// Example:
  /// ```dart
  /// engine.render('users.profile', {'user': user, 'title': 'Profile'});
  /// ```
  String render(String templateName, [Map<String, dynamic>? data]) {
    final templateContent = _loadTemplate(templateName);
    return _compile(templateContent, data ?? {});
  }

  /// Loads template content from disk with caching.
  ///
  /// Converts `dot.notation` → `path/to/file.html`.
  String _loadTemplate(String templateName) {
    if (_cache.containsKey(templateName)) {
      return _cache[templateName]!;
    }

    // Convert dot syntax to file path
    final templatePath = '${viewsDirectory.replaceAll(RegExp(r'/+$'), '')}/${templateName.replaceAll('.', '/')}.html';
    final file = File(templatePath);

    if (!file.existsSync()) {
      throw TemplateEngineException.templateNotFound("html view for '$templateName' was not found.");
    }

    final content = file.readAsStringSync();
    _cache[templateName] = content;
    return content;
  }

  /// Compiles template with all features: layouts, includes, loops, etc.
  String _compile(String content, Map<String, dynamic> data) {
    String result = content;
    result = _processLayouts(result, data);

    result = _processIncludes(result, data);

    result = _processControlStructures(result, data);

    result = _processInterpolations(result, data);
    return result;
  }

  /// Replaces `{{ expr }}` (escaped) and `{!! expr !!}` (raw).
  ///
  /// Supports nested access: `user.profile.name`
  String _processInterpolations(String content, Map<String, dynamic> data) {
    String result = content;

    result = result.replaceAllMapped(RegExp(r'{!!\s*(.*?)\s*!!}'), (match) {
      final expression = match.group(1)!;
      return _evaluateExpression(expression, data).toString();
    });

    result = result.replaceAllMapped(RegExp(r'{{\s*(.*?)\s*}}'), (match) {
      final expression = match.group(1)!;
      final value = _evaluateExpression(expression, data).toString();
      return _escapeHtml(value);
    });

    return result;
  }

  /// Escapes HTML special characters to prevent XSS.
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Evaluates dot-notation expressions against [data].
  ///
  /// Supports:
  /// - Map access: `user.name`
  /// - List indexing: `items.0`
  dynamic _evaluateExpression(String expression, Map<String, dynamic> data) {
    final parts = expression.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        if (current[part] == null) {
          throw TemplateEngineException.variableNotFound("variable($part) was not found");
        }
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        final index = int.parse(part);
        if (index < current.length) {
          current = current[index];
        } else {
          return '';
        }
      } else {
        return '';
      }
    }

    return current ?? '';
  }

  /// Processes `@layout('name')` and `@yield('section')`.
  String _processLayouts(String content, Map<String, dynamic> data) {
    final layoutRegex = RegExp(r'''@layout\(\s*['"]([^'"]+)['"]\s*\)''', dotAll: true);

    final match = layoutRegex.firstMatch(content);
    if (match == null) {
      return content; // No layout directive found
    }

    final layoutName = match.group(1)!;

    final sections = _extractSections(content);

    // Render the layout with sections
    return _renderLayout(layoutName, sections, data);
  }

  /// Extracts `@section('name')...@endsection` blocks.
  Map<String, String> _extractSections(String content) {
    final sectionRegex = RegExp(r'''@section\(\s*['"]([^'"]+)['"]\s*\)(.*?)@endsection''', dotAll: true);

    final sections = <String, String>{};

    sectionRegex.allMatches(content).forEach((match) {
      final sectionName = match.group(1)!;
      final sectionContent = match.group(2)!;
      sections[sectionName] = sectionContent.trim();
    });

    return sections;
  }

  /// Renders layout with injected sections.
  String _renderLayout(String layoutName, Map<String, String> sections, Map<String, dynamic> data) {
    final layoutContent = _loadTemplate(layoutName);

    // Process yields in the layout
    return layoutContent.replaceAllMapped(RegExp(r'''@yield\(\s*['"]([^'"]+)['"]\s*\)''', dotAll: true), (match) {
      final yieldName = match.group(1)!;
      return sections[yieldName] ?? '';
    });
  }

  /// Processes recursive `@include('template', {data})`.
  String _processIncludes(String content, Map<String, dynamic> data) {
    final includeRegex = RegExp(r'''@include\(\s*['"]([^'"]+)['"]\s*(?:,\s*(\{[\s\S]*?\}))?\s*\)''', dotAll: true);

    String process(String text) {
      return text.replaceAllMapped(includeRegex, (match) {
        final templateName = match.group(1)!;
        final jsonString = match.group(2);

        Map<String, dynamic> mergedData = Map<String, dynamic>.from(data);

        if (jsonString != null) {
          try {
            final additionalData = jsonDecode(jsonString) as Map<String, dynamic>;
            mergedData.addAll(additionalData);
          } catch (e) {
            print('Warning: Invalid JSON in include: $jsonString');
          }
        }

        return render(templateName, mergedData);
      });
    }

    /// Recursively resolve nested includes
    String result = content;
    String previousResult;
    do {
      previousResult = result;
      result = process(result);
    } while (result != previousResult && result.contains('@include'));

    return result;
  }
  /// Processes control structures: `@foreach`, `@if`, `@else`, `@endif`.
  String _processControlStructures(String content, Map<String, dynamic> data) {
    String result = content;

    result = _processForeach(result, data);
    result = _processIfStatements(result, data);

    return result;
  }
  /// Implements `@foreach(collection as item)`.
  String _processForeach(String content, Map<String, dynamic> data) {
    final regex = RegExp(r'@foreach\s*\(\s*(\w+)\s+as\s+(\w+)\s*\)(.*?)@endforeach', dotAll: true);

    return content.replaceAllMapped(regex, (match) {
      final collectionName = match.group(1)!;
      final itemName = match.group(2)!;
      final loopContent = match.group(3)!;

      final collection = _evaluateExpression(collectionName, data);

      if (collection is! List) {
        return '';
      }

      final buffer = StringBuffer();

      for (final item in collection) {
        final loopData = Map<String, dynamic>.from(data);
        loopData[itemName] = item;
        buffer.write(_compile(loopContent, loopData));
      }

      return buffer.toString();
    });
  }

  /// Implements `@if(condition)...@else...@endif`.
  String _processIfStatements(String content, Map<String, dynamic> data) {
    final regex = RegExp(r'@if\s*\((.*?)\)(.*?)(?:@else(.*?))?@endif', dotAll: true);

    return content.replaceAllMapped(regex, (match) {
      final condition = match.group(1)!;
      final ifContent = match.group(2)!;
      final elseContent = match.group(3);

      final conditionResult = _evaluateCondition(condition, data);

      if (conditionResult) {
        return ifContent;
      } else if (elseContent != null) {
        return elseContent;
      }

      return '';
    });
  }

  /// Evaluates condition in `@if(...)`.
  ///
  /// Supports:
  /// - `==`, `!=`
  /// - Truthy checks
  bool _evaluateCondition(String condition, Map<String, dynamic> data) {
    condition = condition.trim();

    // Handle comparison operators
    if (condition.contains('==')) {
      final parts = condition.split('==').map((e) => e.trim()).toList();
      final left = _evaluateExpression(parts[0], data);
      final right = _evaluateExpression(parts[1], data) ?? parts[1].replaceAll("'", "").replaceAll('"', '');
      return left == right;
    }

    if (condition.contains('!=')) {
      final parts = condition.split('!=').map((e) => e.trim()).toList();
      final left = _evaluateExpression(parts[0], data);
      final right = _evaluateExpression(parts[1], data) ?? parts[1].replaceAll("'", "").replaceAll('"', '');
      return left != right;
    }

    // Check for existence in data
    final value = _evaluateExpression(condition, data);
    return value != null && value != false && value != '' && value != 0;
  }

  /// Clears template cache (useful in development).
  void clearCache() {
    _cache.clear();
  }
}

/// Type alias for view data.
typedef ViewData = Map<String, dynamic>;

/// Extension on [HttpRequest] to render HTML views.
extension View on HttpRequest {
  /// Renders a template and sends HTML response.
  ///
  /// - Sets `Content-Type: text/html`
  /// - Adds caching and security headers
  /// - Sets XSRF token cookie
  /// - Handles errors gracefully in debug mode
  HttpResponse view(String template, [ViewData? data]) {
    final engine = App().container.make<TemplateEngine>();
    final config = App().container.make<AppConfig>();

    try {
      final html = engine.render(template, data ?? {});

      // --- Performance headers ---
      response.headers.contentType = ContentType.html;
      response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=300, must-revalidate');
      response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
      //
      // // --- Security headers ---
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('X-Frame-Options', 'SAMEORIGIN');
      response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
      response.headers.set('X-XSS-Protection', '1; mode=block');

      final cookie = Cookie('xsrf-token-${config.get('app.timestamp').toString().replaceAll(':', '-')}', "${config.get('app.id')}")
        ..httpOnly = true
        ..secure =
            true // only over HTTPS
        ..sameSite = SameSite.lax;

      return response
        ..cookies.add(cookie)
        ..write(html)
        ..close();
    } catch (e, stack) {
      if (config.get('app.debug')) {
        return response
          ..statusCode = HttpStatus.internalServerError
          ..write("$e\n\n$stack")
          ..close();
      }
      return response
        ..statusCode = HttpStatus.internalServerError
        ..write(e)
        ..close();
    }
  }
}

/// Extension on [HttpRequest] to send JSON responses.
extension Json on HttpRequest {
  /// Sends JSON response with security headers and XSRF cookie.
  HttpResponse json([dynamic data]) {
    final config = App().container.make<AppConfig>();

    // --- Performance headers ---
    response.headers.contentType = ContentType.html;
    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=300, must-revalidate');
    response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
    //
    // // --- Security headers ---
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'SAMEORIGIN');
    response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    response.headers.set('X-XSS-Protection', '1; mode=block');

    final cookie = Cookie('xsrf-json-token-${config.get('app.timestamp').toString().replaceAll(':', '-')}', "${config.get('app.id')}")
      ..httpOnly = true
      ..secure = true
      ..sameSite = SameSite.lax;

    response.headers.contentType = ContentType.json;

    return response
      ..cookies.add(cookie)
      ..write(jsonEncode(data))
      ..close();
  }
}

/// Extension on [HttpRequest] to send plain text.
extension Text on HttpRequest {
  /// Sends plain text response.
  HttpResponse text([dynamic data]) {
    final config = App().container.make<AppConfig>();
    response.headers.contentType = ContentType.html;
    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=300, must-revalidate');
    response.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');

    // --- Security headers ---
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'SAMEORIGIN');
    response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    response.headers.set('X-XSS-Protection', '1; mode=block');

    final cookie = Cookie('xsrf-text-token-${config.get('app.timestamp').toString().replaceAll(':', '-')}', "${config.get('app.id')}")
      ..httpOnly = true
      ..secure = true
      ..sameSite = SameSite.lax;

    response.headers.contentType = ContentType.text;
    return response
      ..statusCode = HttpStatus.ok
      ..cookies.add(cookie)
      ..write(data)
      ..close();
  }
}

/// Extension on [HttpRequest] to send 404 with fallback template.
extension NotFound on HttpRequest {
  /// Renders `errors.404` template or plain 404.
  HttpResponse notFound() {
    final engine = App().container.make<TemplateEngine>();

    try {
      final html = engine.render("errors.404");
      response.headers.contentType = ContentType.html;
      return response
        ..statusCode = HttpStatus.notFound
        ..write(html)
        ..close();
    } catch (e) {
      return response
        ..statusCode = HttpStatus.notFound
        ..write("404 Not Found")
        ..close();
    }
  }
}
