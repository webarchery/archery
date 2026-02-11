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
base class TemplateEngineException implements Exception {
  String? message;

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

/// A powerful, Laravel Blade-inspired templating engine for Dart.
///
/// Supports layouts, includes, control structures, and secure interpolation.
///
/// **Async Support:** render() and internal processing are now asynchronous
/// to prevent blocking the event loop on file I/O.
base class TemplateEngine {
  /// Directory containing `.html` view templates.
  final String viewsDirectory;

  /// Public assets directory.
  final String publicDirectory;

  /// In-memory cache of compiled template content.
  final Map<String, String> _cache = {};

  /// Whether to enable template caching.
  ///
  /// Set to `false` during development for automatic template reloading.
  /// Set to `true` in production for better performance.
  bool shouldCache = false;

  /// Creates a new template engine instance.
  /// [publicDirectory] not necessary but provided for future directives
  TemplateEngine({required this.viewsDirectory, required this.publicDirectory});

  /// Renders a template with the provided data asynchronously.
  Future<String> render(String templateName, [Map<String, dynamic>? data]) async {
    final templateContent = await _loadTemplate(templateName);
    return _compile(templateContent, data ?? {});
  }

  /// Loads template content from disk with optional caching.
  ///
  /// Uses async I/O.
  Future<String> _loadTemplate(String templateName) async {
    if (shouldCache) {
      if (_cache.containsKey(templateName)) {
        return _cache[templateName]!;
      }
    }

    // Convert dot syntax to file path
    final templatePath =
        '${viewsDirectory.replaceAll(RegExp(r'/+$'), '')}/'
        '${templateName.replaceAll('.', '/')}.html';

    final file = File(templatePath);

    if (!await file.exists()) {
      throw TemplateEngineException.templateNotFound("HTML view for '$templateName' was not found at path: $templatePath");
    }

    final content = await file.readAsString();
    if (shouldCache) {
      _cache[templateName] = content;
    }
    return content;
  }

  /// Compiles template content through the full processing pipeline.
  Future<String> _compile(String content, Map<String, dynamic> data) async {
    String result = content;

    // Process layouts first as they define the overall structure
    result = await _processLayouts(result, data);

    // Process includes to resolve partial templates
    result = await _processIncludes(result, data);

    // Process control structures (loops and conditionals)
    result = await _processControlStructures(result, data);

    // Process CSRF directive
    result = _processCsrf(result, data);

    // Process interpolations last (variables and expressions)
    // Interpolation is CPU-bound string manipulation, so it remains sync-style
    // but called within this async flow.
    result = _processInterpolations(result, data);

    return result;
  }

  // --- Async Regex Helper ---

  /// Asynchronously replaces matches in a string.
  ///
  /// Dart's [replaceAllMapped] does not support async callbacks.
  Future<String> _replaceAllMappedAsync(String input, RegExp regex, Future<String> Function(Match match) replace) async {
    final StringBuffer buffer = StringBuffer();
    int lastIndex = 0;

    for (final match in regex.allMatches(input)) {
      buffer.write(input.substring(lastIndex, match.start));
      buffer.write(await replace(match));
      lastIndex = match.end;
    }

    buffer.write(input.substring(lastIndex));
    return buffer.toString();
  }

  // --- Processing Methods ---

  String _processInterpolations(String content, Map<String, dynamic> data) {
    String result = content;

    // Process unescaped interpolations {!! !!} first
    result = result.replaceAllMapped(RegExp(r'{!!\s*(.*?)\s*!!}'), (match) {
      final expression = match.group(1)!;
      return _evaluateInterpolation(expression, data).toString();
    });

    // Process escaped interpolations {{ }} second
    result = result.replaceAllMapped(RegExp(r'{{\s*(.*?)\s*}}'), (match) {
      final expression = match.group(1)!;
      final value = _evaluateInterpolation(expression, data).toString();
      return _escapeHtml(value);
    });

    return result;
  }

  dynamic _evaluateInterpolation(String expression, Map<String, dynamic> data) {
    expression = expression.trim();
    if (expression.isEmpty) return '';

    // Handle string literals
    if ((expression.startsWith("'") && expression.endsWith("'")) || (expression.startsWith('"') && expression.endsWith('"'))) {
      return expression.substring(1, expression.length - 1);
    }

    // Handle numbers
    if (RegExp(r'^-?\d+$').hasMatch(expression)) {
      return int.tryParse(expression) ?? expression;
    }
    if (RegExp(r'^-?\d+\.\d+$').hasMatch(expression)) {
      return double.tryParse(expression) ?? expression;
    }

    // Handle booleans/null
    if (expression == 'true') return true;
    if (expression == 'false') return false;
    if (expression == 'null') return null;

    // Handle arithmetic
    if (expression.contains('+') || expression.contains('-') || expression.contains('*') || expression.contains('/')) {
      return _evaluateArithmetic(expression, data);
    }

    // Handle method calls
    if (expression.contains('(') && expression.contains(')')) {
      return _evaluateMethodCall(expression, data);
    }

    // Default variable lookup
    return _evaluateExpression(expression, data);
  }

  dynamic _evaluateArithmetic(String expression, Map<String, dynamic> data) {
    try {
      var processed = expression;
      final variablePattern = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*');

      for (final match in variablePattern.allMatches(expression)) {
        final varName = match.group(0)!;
        if (!_isOperator(varName)) {
          final value = _evaluateExpression(varName, data);
          processed = processed.replaceFirst(varName, value.toString());
        }
      }

      if (processed.contains('+')) {
        final parts = processed.split('+');
        final left = num.tryParse(parts[0].trim()) ?? 0;
        final right = num.tryParse(parts[1].trim()) ?? 0;
        return left + right;
      }

      return processed;
    } catch (e) {
      return expression;
    }
  }

  bool _isOperator(String token) {
    return token == '+' || token == '-' || token == '*' || token == '/';
  }

  dynamic _evaluateMethodCall(String expression, Map<String, dynamic> data) {
    try {
      if (!expression.endsWith(')')) {
        return _evaluateExpression(expression, data);
      }

      final methodMatch = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*)\(\)$').firstMatch(expression);

      if (methodMatch != null) {
        final propertyPath = methodMatch.group(1)!;
        return _evaluateExpression(propertyPath, data);
      }

      final propertyPath = expression.replaceAll(RegExp(r'\(\)$'), '');
      return _evaluateExpression(propertyPath, data);
    } catch (e) {
      return expression;
    }
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
        if (!current.containsKey(part)) {
          return '';
        }
        current = current[part];
      } else if (current is List) {
        if (int.tryParse(part) != null) {
          final index = int.parse(part);
          if (index < current.length) {
            current = current[index];
          } else {
            return '';
          }
        } else if (part == 'length') {
          return current.length;
        } else if (part == 'isEmpty') {
          return current.isEmpty;
        } else if (part == 'isNotEmpty') {
          return current.isNotEmpty;
        } else {
          return '';
        }
      } else if (current is String) {
        if (part == 'length') {
          return current.length;
        } else if (part == 'isEmpty') {
          return current.isEmpty;
        } else if (part == 'isNotEmpty') {
          return current.isNotEmpty;
        } else {
          return '';
        }
      } else if (current == null) {
        return '';
      } else {
        try {
          if (part == 'toString') {
            return current.toString();
          }
          return '';
        } catch (e) {
          return '';
        }
      }
    }

    return current ?? '';
  }

  Future<String> _processLayouts(String content, Map<String, dynamic> data) async {
    final layoutRegex = RegExp(r'''@layout\(\s*['"]([^'"]+)['"]\s*\)''', dotAll: true);

    final match = layoutRegex.firstMatch(content);
    if (match == null) {
      return content;
    }

    final layoutName = match.group(1)!;
    final sections = _extractSections(content);

    return _renderLayout(layoutName, sections, data);
  }

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

  Future<String> _renderLayout(String layoutName, Map<String, String> sections, Map<String, dynamic> data) async {
    final layoutContent = await _loadTemplate(layoutName);

    // Using _replaceAllMappedAsync isn't strictly necessary here if yield replacements are simple text
    // but _loadTemplate was async, so this function is async.
    // The yields themselves are sync replacements from the `sections` map.
    return layoutContent.replaceAllMapped(RegExp(r'''@yield\(\s*['"]([^'"]+)['"]\s*\)''', dotAll: true), (match) {
      final yieldName = match.group(1)!;
      return sections[yieldName] ?? '';
    });
  }

  Future<String> _processIncludes(String content, Map<String, dynamic> data) async {
    final includeRegex = RegExp(r'''@include\(\s*['"]([^'"]+)['"]\s*(?:,\s*(\{[\s\S]*?\}))?\s*\)''', dotAll: true);

    Future<String> process(String text) {
      return _replaceAllMappedAsync(text, includeRegex, (match) async {
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

        return await render(templateName, mergedData);
      });
    }

    String result = content;
    String previousResult;
    do {
      previousResult = result;
      result = await process(result);
    } while (result != previousResult && result.contains('@include'));

    return result;
  }

  Future<String> _processControlStructures(String content, Map<String, dynamic> data) async {
    String result = content;

    result = await _processForeach(result, data);
    result = _processIfStatements(result, data);

    return result;
  }

  Future<String> _processForeach(String content, Map<String, dynamic> data) async {
    final regex = RegExp(r'@foreach\s*\(\s*(\w+)\s+as\s+(\w+)\s*\)(.*?)@endforeach', dotAll: true);

    return _replaceAllMappedAsync(content, regex, (match) async {
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
        buffer.write(await _compile(loopContent, loopData));
      }

      return buffer.toString();
    });
  }

  String _processCsrf(String content, Map<String, dynamic> data) {
    if (!content.contains('@csrf')) return content;

    final token = data['csrf_token'] as String? ?? '';
    final input = '<input type="hidden" name="_token" value="$token">';
    return content.replaceAll('@csrf', input);
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

    if (condition.contains('==')) {
      final parts = condition.split('==').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      return left == right;
    }

    if (condition.contains('!=')) {
      final parts = condition.split('!=').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      return left != right;
    }

    if (condition.contains('>=')) {
      final parts = condition.split('>=').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      if (left is num && right is num) return left >= right;
    }

    if (condition.contains('<=')) {
      final parts = condition.split('<=').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      if (left is num && right is num) return left <= right;
    }

    if (condition.contains('>')) {
      final parts = condition.split('>').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      if (left is num && right is num) return left > right;
    }

    if (condition.contains('<')) {
      final parts = condition.split('<').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      if (left is num && right is num) return left < right;
    }

    if (condition == 'true') return true;
    if (condition == 'false') return false;

    if (condition.startsWith('!')) {
      final subCondition = condition.substring(1).trim();
      return !_evaluateCondition(subCondition, data);
    }

    final value = _evaluateInterpolation(condition, data);
    return value != null && value != false && value != '' && value != 0;
  }

  void clearCache() {
    _cache.clear();
  }
}
