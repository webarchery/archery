import 'package:archery/archery/archery.dart';

class TemplateEngine {
  final String viewsDirectory;
  final String publicDirectory;
  final Map<String, String> _cache = {};

  TemplateEngine({
    required this.viewsDirectory,
    required this.publicDirectory,
  });

  String render(String templateName, [Map<String, dynamic>? data]) {
    final templateContent = _loadTemplate(templateName);
    return _compile(templateContent, data ?? {});
  }

  String _loadTemplate(String templateName) {
    // Check cache first
    if (_cache.containsKey(templateName)) {
      return _cache[templateName]!;
    }

    // Convert dot syntax to file path
    final templatePath = '${viewsDirectory.replaceAll(RegExp(r'/+$'), '')}/${templateName.replaceAll('.', '/')}.html';
    final file = File(templatePath);

    if (!file.existsSync()) {

      throw Exception('Template not found: $templatePath');
      // return _loadTemplate('errors.template404');
    }

    final content = file.readAsStringSync();
    _cache[templateName] = content;
    return content;
  }

  String _compile(String content, Map<String, dynamic> data) {
    String result = content;

    result = _processLayouts(result, data);

    result = _processStaticAssets(result);

    result = _processIncludes(result, data);

    result = _processControlStructures(result, data);

    result = _processInterpolations(result, data);

    return result;
  }

  String _processStaticAssets(String content) {
    String result = content;

    // Process CSS assets
    result = result.replaceAllMapped(RegExp(r'''@css\(\s*['"]([^'"]+)['"]\s*\)'''), (match) {
      final filename = match.group(1)!;
      return _loadCssAsset(filename);
    });

    // Process JavaScript assets
    result = result.replaceAllMapped(RegExp(r'''@script\(\s*['"]([^'"]+)['"]\s*\)'''), (match) {
      final filename = match.group(1)!;
      return _loadScriptAsset(filename);
    });

    return result;
  }

  String _loadCssAsset(String filename) {
    _validateFilename(filename);
    _validateFileExtension(filename, '.css');

    final cssPath = '${publicDirectory.replaceAll(RegExp(r'/+$'), '')}/css/$filename';
    final file = File(cssPath);

    if (!file.existsSync()) {
      throw Exception('CSS asset not found: $cssPath');
    }

    final cssContent = file.readAsStringSync();
    return '<style>\n$cssContent\n</style>';
  }

  String _loadScriptAsset(String filename) {
    _validateFilename(filename);
    _validateFileExtension(filename, '.js');

    final jsPath = '${publicDirectory.replaceAll(RegExp(r'/+$'), '')}/js/$filename';
    final file = File(jsPath);

    if (!file.existsSync()) {
      throw Exception('Script asset not found: $jsPath');
    }

    final jsContent = file.readAsStringSync();
    return '<script>\n$jsContent\n</script>';
  }

  void _validateFilename(String filename) {
    if (filename.contains('..') || filename.contains('/') || filename.contains('\\')) {
      throw Exception('Security violation: Filename cannot contain path traversal characters: $filename');
    }

    if (filename.contains('\x00')) {
      throw Exception('Security violation: Filename contains null byte: $filename');
    }

    if (filename.startsWith('/') || RegExp(r'^[a-zA-Z]:\\').hasMatch(filename)) {
      throw Exception('Security violation: Filename cannot be an absolute path: $filename');
    }

    if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(filename)) {
      throw Exception('Security violation: Invalid filename characters: $filename');
    }
  }

  void _validateFileExtension(String filename, String expectedExtension) {
    if (!filename.toLowerCase().endsWith(expectedExtension)) {
      throw Exception('File $filename must have $expectedExtension extension');
    }
  }

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

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  dynamic _evaluateExpression(String expression, Map<String, dynamic> data) {
    final parts = expression.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
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

  String _processLayouts(String content, Map<String, dynamic> data) {
    final layoutRegex = RegExp(
      r'''@layout\(\s*['"]([^'"]+)['"]\s*\)''',
      dotAll: true,
    );

    final match = layoutRegex.firstMatch(content);
    if (match == null) {
      return content; // No layout directive found
    }

    final layoutName = match.group(1)!;

    final sections = _extractSections(content);

    // final contentWithoutLayout = content.replaceAll(layoutRegex, '');

    // Render the layout with sections
    return _renderLayout(layoutName, sections, data);
  }

  Map<String, String> _extractSections(String content) {
    final sectionRegex = RegExp(
      r'''@section\(\s*['"]([^'"]+)['"]\s*\)(.*?)@endsection''',
      dotAll: true,
    );

    final sections = <String, String>{};

    sectionRegex.allMatches(content).forEach((match) {
      final sectionName = match.group(1)!;
      final sectionContent = match.group(2)!;
      sections[sectionName] = sectionContent.trim();
    });

    return sections;
  }

  String _renderLayout(String layoutName, Map<String, String> sections, Map<String, dynamic> data) {
    final layoutContent = _loadTemplate(layoutName);

    // Process yields in the layout
    return layoutContent.replaceAllMapped(RegExp(
      r'''@yield\(\s*['"]([^'"]+)['"]\s*\)''',
      dotAll: true,
    ), (match) {
      final yieldName = match.group(1)!;
      return sections[yieldName] ?? '';
    });
  }

  String _processIncludes(String content, Map<String, dynamic> data) {
    final includeRegex = RegExp(
      r'''@include\(\s*['"]([^'"]+)['"]\s*(?:,\s*(\{[\s\S]*?\}))?\s*\)''',
      dotAll: true,
    );

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

    // Process includes recursively
    String result = content;
    String previousResult;
    do {
      previousResult = result;
      result = process(result);
    } while (result != previousResult && result.contains('@include'));

    return result;
  }

  String _processControlStructures(String content, Map<String, dynamic> data) {
    String result = content;

    result = _processForeach(result, data);
    result = _processIfStatements(result, data);

    return result;
  }

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

  void clearCache() {
    _cache.clear();
  }
}


typedef ViewData = Map<String, dynamic>;
extension View on HttpRequest {

  HttpResponse view(String template, [ViewData? data]) {
    final engine = App().container.make<TemplateEngine>();
    final html = engine.render(template, data ?? {});

    final res = response;
    final config = App().container.make<AppConfig>();

    // --- Performance headers ---
    res.headers.contentType = ContentType.html;
    res.headers.set(HttpHeaders.cacheControlHeader,
        'public, max-age=300, must-revalidate');
    res.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
    //
    // // --- Security headers ---
    res.headers.set('X-Content-Type-Options', 'nosniff');
    res.headers.set('X-Frame-Options', 'SAMEORIGIN');
    res.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.headers.set('X-XSS-Protection', '1; mode=block');


    final cookie = Cookie(
      'xsrf-token-${config.get('app.timestamp').toString().replaceAll(':', '-')}',
      "${config.get('app.id')}",
    )
      ..httpOnly = true
      ..secure = true // only over HTTPS
      ..sameSite = SameSite.lax;

    return res
      ..cookies.add(cookie)
      ..write(html)
      ..close();
  }
}


extension Json on HttpRequest {
  HttpResponse json([dynamic data]) {
    final config = App().container.make<AppConfig>();

    final cookie = Cookie(
      'xsrf-api-token-${config.get('app.timestamp').toString().replaceAll(':', '-')}',
      "${config.get('app.id')}",
    )
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

extension Text on HttpRequest {

  HttpResponse text([dynamic data]) {

    response.headers.contentType = ContentType.text;
    return response
      ..statusCode = HttpStatus.ok
      ..write(data)
      ..close();
  }
}



extension NotFound on HttpRequest {

  HttpResponse notFound() {

    final engine = App().container.make<TemplateEngine>();

    try {
      final html = engine.render("errors.404");
      response.headers.contentType = ContentType.html;
      return response
        ..statusCode = HttpStatus.notFound
        ..write(html)
        ..close();
    } catch(e) {
      return response
        ..statusCode = HttpStatus.notFound
        ..write("404 Not Found")
        ..close();

    }

  }
}






