

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


/// A powerful, Laravel Blade-inspired templating engine for Dart.
///
/// Supports layouts, includes, control structures, and secure interpolation.
///
/// Example:
/// ```dart
/// final engine = TemplateEngine(
///   viewsDirectory: 'views',
///   publicDirectory: 'public',
/// );
///
/// final html = engine.render('users.profile', {
///   'user': user,
///   'title': 'User Profile'
/// });
/// ```
class TemplateEngine {
  /// Directory containing `.html` view templates.
  ///
  /// Templates use dot notation: `users.profile` → `views/users/profile.html`
  final String viewsDirectory;

  /// Public assets directory (not used directly by engine).
  ///
  /// This is provided for consistency but static asset handling
  /// would be implemented separately in your application.
  final String publicDirectory;

  /// In-memory cache of compiled template content.
  ///
  /// Improves performance by avoiding repeated file reads.
  /// Can be cleared with [clearCache()].
  final Map<String, String> _cache = {};

  /// Whether to enable template caching.
  ///
  /// Set to `false` during development for automatic template reloading.
  /// Set to `true` in production for better performance.
  bool shouldCache = false;

  /// Creates a new template engine instance.
  ///
  /// - [viewsDirectory]: Required. Base path for template files.
  /// - [publicDirectory]: Required. Base path for static assets.
  ///
  /// Example:
  /// ```dart
  /// final engine = TemplateEngine(
  ///   viewsDirectory: 'resources/views',
  ///   publicDirectory: 'public',
  /// );
  /// ```
  TemplateEngine({required this.viewsDirectory, required this.publicDirectory});

  /// Renders a template with the provided data.
  ///
  /// - [templateName]: Template path using dot notation (e.g., 'users.profile')
  /// - [data]: Optional data map to make available in the template
  ///
  /// Returns the rendered HTML as a string.
  ///
  /// Example:
  /// ```dart
  /// final html = engine.render('users.profile', {
  ///   'user': user,
  ///   'title': 'Profile Page',
  ///   'items': itemsList,
  /// });
  /// ```
  ///
  /// Throws [TemplateEngineException.templateNotFound] if template is not found.
  String render(String templateName, [Map<String, dynamic>? data]) {
    final templateContent = _loadTemplate(templateName);
    return _compile(templateContent, data ?? {});
  }

  /// Loads template content from disk with optional caching.
  ///
  /// Converts dot notation to file system path:
  /// - `users.profile` → `views/users/profile.html`
  /// - `admin.dashboard` → `views/admin/dashboard.html`
  ///
  /// Throws [TemplateEngineException] if template file is not found.
  String _loadTemplate(String templateName) {
    // TODO: Implement caching when shouldCache is true
    // if (shouldCache) {
    //   if (_cache.containsKey(templateName)) {
    //     return _cache[templateName]!;
    //   }
    // }

    // Convert dot syntax to file path
    final templatePath =
        '${viewsDirectory.replaceAll(RegExp(r'/+$'), '')}/'
        '${templateName.replaceAll('.', '/')}.html';

    final file = File(templatePath);

    if (!file.existsSync()) {
      throw TemplateEngineException.templateNotFound(
          "HTML view for '$templateName' was not found at path: $templatePath");
    }

    final content = file.readAsStringSync();
    _cache[templateName] = content; // Cache for potential future use
    return content;
  }

  /// Compiles template content through the full processing pipeline.
  ///
  /// Processing order:
  /// 1. Layouts (`@layout` and `@yield`)
  /// 2. Includes (`@include`)
  /// 3. Control structures (`@if`, `@foreach`)
  /// 4. Interpolations (`{{ }}` and `{!! !!}`)
  ///
  /// This order ensures dependencies are resolved correctly.
  String _compile(String content, Map<String, dynamic> data) {
    String result = content;

    // Process layouts first as they define the overall structure
    result = _processLayouts(result, data);

    // Process includes to resolve partial templates
    result = _processIncludes(result, data);

    // Process control structures (loops and conditionals)
    result = _processControlStructures(result, data);

    // Process interpolations last (variables and expressions)
    result = _processInterpolations(result, data);

    return result;
  }

  /// Processes template interpolations for variables and expressions.
  ///
  /// Supports two types of interpolation:
  /// - `{{ expression }}` - HTML escaped output (secure)
  /// - `{!! expression !!}` - Raw output (use with caution)
  ///
  /// Expressions can be:
  /// - Variables: `user.name`, `items.0.title`
  /// - Literals: `'Hello'`, `42`, `true`, `null`
  /// - Simple arithmetic: `count + 1`, `total / 2`
  /// - Properties: `items.length`, `user.name.isEmpty`
  ///
  /// Example:
  /// ```html
  /// <h1>{{ title }}</h1>
  /// <p>Welcome, {{ user.name }}!</p>
  /// <div>{!! rawHtml !!}</div>
  /// <span>Total: {{ items.length + 1 }}</span>
  /// ```
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

  /// Evaluates an interpolation expression with support for various types.
  ///
  /// Supported expression types:
  /// - String literals: `'text'`, `"text"`
  /// - Numbers: `42`, `3.14`, `-5`
  /// - Booleans: `true`, `false`
  /// - Null: `null`
  /// - Variables: `user.name`, `items.0`
  /// - Arithmetic: `count + 1`, `total - discount`
  /// - Properties: `items.length`, `name.isEmpty`
  ///
  /// Returns the evaluated value or empty string on error.
  dynamic _evaluateInterpolation(String expression, Map<String, dynamic> data) {
    expression = expression.trim();

    // Handle empty expressions
    if (expression.isEmpty) return '';

    // Handle string literals (both single and double quotes)
    if ((expression.startsWith("'") && expression.endsWith("'")) ||
        (expression.startsWith('"') && expression.endsWith('"'))) {
      return expression.substring(1, expression.length - 1);
    }

    // Handle integer numbers
    if (RegExp(r'^-?\d+$').hasMatch(expression)) {
      return int.tryParse(expression) ?? expression;
    }

    // Handle decimal numbers
    if (RegExp(r'^-?\d+\.\d+$').hasMatch(expression)) {
      return double.tryParse(expression) ?? expression;
    }

    // Handle boolean literals
    if (expression == 'true') return true;
    if (expression == 'false') return false;
    if (expression == 'null') return null;

    // Handle simple arithmetic expressions
    if (expression.contains('+') || expression.contains('-') ||
        expression.contains('*') || expression.contains('/')) {
      return _evaluateArithmetic(expression, data);
    }

    // Handle method-like calls (treated as property access)
    if (expression.contains('(') && expression.contains(')')) {
      return _evaluateMethodCall(expression, data);
    }

    // Default to variable lookup using dot notation
    return _evaluateExpression(expression, data);
  }

  /// Evaluates simple arithmetic expressions within templates.
  ///
  /// Supports basic operations: `+`, `-`, `*`, `/`
  /// Can mix variables and literals: `items.length + 1`
  ///
  /// Note: This is a basic implementation. For complex expressions,
  /// consider using a proper expression evaluator.
  dynamic _evaluateArithmetic(String expression, Map<String, dynamic> data) {
    try {
      // Extract variables and replace with their values
      var processed = expression;
      final variablePattern = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*');

      for (final match in variablePattern.allMatches(expression)) {
        final varName = match.group(0)!;
        if (!_isOperator(varName)) {
          final value = _evaluateExpression(varName, data);
          processed = processed.replaceFirst(varName, value.toString());
        }
      }

      // Basic arithmetic evaluation
      // Note: This is simplified - production should use proper expression parsing
      if (processed.contains('+')) {
        final parts = processed.split('+');
        final left = num.tryParse(parts[0].trim()) ?? 0;
        final right = num.tryParse(parts[1].trim()) ?? 0;
        return left + right;
      }

      // TODO: Add support for other operators as needed
      // Currently only addition is implemented for demonstration

      return processed;
    } catch (e) {
      // Return original expression if evaluation fails
      return expression;
    }
  }

  /// Checks if a token is an arithmetic operator.
  bool _isOperator(String token) {
    return token == '+' || token == '-' || token == '*' || token == '/';
  }

  /// Evaluates method-like calls in expressions.
  ///
  /// Currently treats all method-looking calls as property access.
  /// For example: `items.length()` becomes `items.length`
  ///
  /// This provides a familiar syntax while maintaining simplicity.
  dynamic _evaluateMethodCall(String expression, Map<String, dynamic> data) {
    try {
      // Handle property access without actual method calls
      if (!expression.endsWith(')')) {
        return _evaluateExpression(expression, data);
      }

      // Extract what looks like a method name
      final methodMatch = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*)\(\)$')
          .firstMatch(expression);

      if (methodMatch != null) {
        final propertyPath = methodMatch.group(1)!;
        return _evaluateExpression(propertyPath, data);
      }

      // Fallback: remove parentheses and treat as property
      final propertyPath = expression.replaceAll(RegExp(r'\(\)$'), '');
      return _evaluateExpression(propertyPath, data);
    } catch (e) {
      return expression; // Return original on error
    }
  }

  /// Escapes HTML special characters to prevent XSS attacks.
  ///
  /// Converts:
  /// - `&` → `&amp;`
  /// - `<` → `&lt;`
  /// - `>` → `&gt;`
  /// - `"` → `&quot;`
  /// - `'` → `&#x27;`
  /// - `/` → `&#x2F;`
  ///
  /// Always use this for `{{ }}` interpolations with user content.
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Evaluates dot-notation expressions against the data context.
  ///
  /// Supports complex object navigation:
  /// - Map access: `user.profile.name`
  /// - List indexing: `items.0.title`
  /// - Common properties: `items.length`, `name.isEmpty`
  ///
  /// Returns empty string if any part of the path is not found,
  /// preventing template rendering errors.
  dynamic _evaluateExpression(String expression, Map<String, dynamic> data) {
    final parts = expression.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(part)) {
          // Graceful failure - return empty string instead of throwing
          return '';
        }
        current = current[part];
      } else if (current is List) {
        // Handle list indexing and common list properties
        if (int.tryParse(part) != null) {
          final index = int.parse(part);
          if (index < current.length) {
            current = current[index];
          } else {
            return ''; // Index out of bounds
          }
        } else if (part == 'length') {
          return current.length;
        } else if (part == 'isEmpty') {
          return current.isEmpty;
        } else if (part == 'isNotEmpty') {
          return current.isNotEmpty;
        } else {
          return ''; // Unknown list property
        }
      } else if (current is String) {
        // Handle common string properties
        if (part == 'length') {
          return current.length;
        } else if (part == 'isEmpty') {
          return current.isEmpty;
        } else if (part == 'isNotEmpty') {
          return current.isNotEmpty;
        } else {
          return ''; // Unknown string property
        }
      } else if (current == null) {
        return ''; // Null safety
      } else {
        // For other types, provide common property access
        try {
          if (part == 'toString') {
            return current.toString();
          }
          // Add more common properties as needed
          return '';
        } catch (e) {
          return ''; // Graceful failure
        }
      }
    }

    return current ?? ''; // Ensure null returns empty string
  }

  /// Processes layout directives for template inheritance.
  ///
  /// Supports Laravel-style layout system:
  /// - `@layout('layouts.app')` - Specifies master layout
  /// - `@section('name')...@endsection` - Defines content sections
  /// - `@yield('name')` - Renders sections in layout
  ///
  /// Example:
  /// ```html
  /// <!-- view.html -->
  /// @layout('layouts.app')
  /// @section('title') Page Title @endsection
  /// @section('content') Page content... @endsection
  ///
  /// <!-- layouts/app.html -->
  /// <html><title>@yield('title')</title><body>@yield('content')</body></html>
  /// ```
  String _processLayouts(String content, Map<String, dynamic> data) {
    final layoutRegex = RegExp(r'''@layout\(\s*['"]([^'"]+)['"]\s*\)''', dotAll: true);

    final match = layoutRegex.firstMatch(content);
    if (match == null) {
      return content; // No layout directive found
    }

    final layoutName = match.group(1)!;
    final sections = _extractSections(content);

    // Render the layout with injected sections
    return _renderLayout(layoutName, sections, data);
  }

  /// Extracts section blocks from template content.
  ///
  /// Finds all `@section('name')...@endsection` blocks and
  /// returns them as a map of section names to content.
  Map<String, String> _extractSections(String content) {
    final sectionRegex = RegExp(
        r'''@section\(\s*['"]([^'"]+)['"]\s*\)(.*?)@endsection''',
        dotAll: true);

    final sections = <String, String>{};

    sectionRegex.allMatches(content).forEach((match) {
      final sectionName = match.group(1)!;
      final sectionContent = match.group(2)!;
      sections[sectionName] = sectionContent.trim();
    });

    return sections;
  }

  /// Renders a layout template with section content injected.
  ///
  /// Replaces all `@yield('sectionName')` directives in the layout
  /// with the corresponding section content.
  String _renderLayout(String layoutName, Map<String, String> sections, Map<String, dynamic> data) {
    final layoutContent = _loadTemplate(layoutName);

    // Replace yield directives with section content
    return layoutContent.replaceAllMapped(
        RegExp(r'''@yield\(\s*['"]([^'"]+)['"]\s*\)''', dotAll: true),
            (match) {
          final yieldName = match.group(1)!;
          return sections[yieldName] ?? ''; // Empty string if section not found
        });
  }

  /// Processes include directives for template partials.
  ///
  /// Supports including other templates with optional data:
  /// - `@include('partials.header')` - Basic include
  /// - `@include('components.card', {'title': 'Hello'})` - Include with data
  ///
  /// Includes are processed recursively, allowing nested includes.
  /// Additional data is merged with the parent template's data.
  String _processIncludes(String content, Map<String, dynamic> data) {
    final includeRegex = RegExp(
        r'''@include\(\s*['"]([^'"]+)['"]\s*(?:,\s*(\{[\s\S]*?\}))?\s*\)''',
        dotAll: true);

    /// Processes a single pass of include directives
    String process(String text) {
      return text.replaceAllMapped(includeRegex, (match) {
        final templateName = match.group(1)!;
        final jsonString = match.group(2);

        // Start with parent data
        Map<String, dynamic> mergedData = Map<String, dynamic>.from(data);

        // Merge include-specific data if provided
        if (jsonString != null) {
          try {
            final additionalData = jsonDecode(jsonString) as Map<String, dynamic>;
            mergedData.addAll(additionalData);
          } catch (e) {
            print('Warning: Invalid JSON in include: $jsonString');
          }
        }

        // Recursively render the included template
        return render(templateName, mergedData);
      });
    }

    // Process includes recursively until no more are found
    String result = content;
    String previousResult;
    do {
      previousResult = result;
      result = process(result);
    } while (result != previousResult && result.contains('@include'));

    return result;
  }

  /// Processes all control structures in the template.
  ///
  /// Currently supports:
  /// - `@foreach` loops
  /// - `@if` / `@else` / `@endif` conditionals
  ///
  /// Control structures are processed after layouts and includes
  /// but before variable interpolation.
  String _processControlStructures(String content, Map<String, dynamic> data) {
    String result = content;

    result = _processForeach(result, data);
    result = _processIfStatements(result, data);

    return result;
  }

  /// Implements `@foreach` loops for iterating over collections.
  ///
  /// Syntax: `@foreach(collection as item) ... @endforeach`
  ///
  /// - `collection`: Variable name of list to iterate over
  /// - `item`: Variable name for current iteration item
  ///
  /// Example:
  /// ```html
  /// @foreach(users as user)
  ///   <div class="user">{{ user.name }}</div>
  /// @endforeach
  /// ```
  String _processForeach(String content, Map<String, dynamic> data) {
    final regex = RegExp(r'@foreach\s*\(\s*(\w+)\s+as\s+(\w+)\s*\)(.*?)@endforeach', dotAll: true);

    return content.replaceAllMapped(regex, (match) {
      final collectionName = match.group(1)!;
      final itemName = match.group(2)!;
      final loopContent = match.group(3)!;

      final collection = _evaluateExpression(collectionName, data);

      if (collection is! List) {
        return ''; // Silently skip if collection is not a list
      }

      final buffer = StringBuffer();

      for (final item in collection) {
        // Create new data context for each iteration
        final loopData = Map<String, dynamic>.from(data);
        loopData[itemName] = item;
        buffer.write(_compile(loopContent, loopData));
      }

      return buffer.toString();
    });
  }

  /// Implements conditional statements with `@if`, `@else`, `@endif`.
  ///
  /// Supports complex conditions with comparison operators and boolean logic.
  ///
  /// Syntax:
  /// ```html
  /// @if(condition)
  ///   Content when true
  /// @else
  ///   Content when false (optional)
  /// @endif
  /// ```
  ///
  /// Condition examples:
  /// - `user.isAdmin`
  /// - `items.length > 0`
  /// - `user.age >= 18`
  /// - `!user.isActive`
  /// - `role == 'admin'`
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

      return ''; // No content if condition false and no else block
    });
  }

  /// Evaluates conditions for `@if` statements.
  ///
  /// Supports a wide range of condition types:
  /// - Comparison: `==`, `!=`, `>`, `<`, `>=`, `<=`
  /// - Boolean literals: `true`, `false`
  /// - Negation: `!condition`
  /// - Truthiness: variables that are not null, false, empty, or zero
  ///
  /// Uses the same expression evaluator as interpolations for consistency.
  bool _evaluateCondition(String condition, Map<String, dynamic> data) {
    condition = condition.trim();

    // Handle comparison operators with proper expression evaluation
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

    // Handle greater than or equal
    if (condition.contains('>=')) {
      final parts = condition.split('>=').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      if (left is num && right is num) return left >= right;
    }

    // Handle less than or equal
    if (condition.contains('<=')) {
      final parts = condition.split('<=').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      if (left is num && right is num) return left <= right;
    }

    // Handle greater than
    if (condition.contains('>')) {
      final parts = condition.split('>').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      if (left is num && right is num) return left > right;
    }

    // Handle less than
    if (condition.contains('<')) {
      final parts = condition.split('<').map((e) => e.trim()).toList();
      final left = _evaluateInterpolation(parts[0], data);
      final right = _evaluateInterpolation(parts[1], data);
      if (left is num && right is num) return left < right;
    }

    // Handle boolean literals directly
    if (condition == 'true') return true;
    if (condition == 'false') return false;

    // Handle negation operator
    if (condition.startsWith('!')) {
      final subCondition = condition.substring(1).trim();
      return !_evaluateCondition(subCondition, data);
    }

    // Default: check for truthiness (not null, false, empty, or zero)
    final value = _evaluateInterpolation(condition, data);
    return value != null && value != false && value != '' && value != 0;
  }

  /// Clears the internal template cache.
  ///
  /// Useful during development when templates are frequently modified.
  /// In production, caching should generally remain enabled for performance.
  ///
  /// Example:
  /// ```dart
  /// // In development mode
  /// engine.clearCache();
  /// ```
  void clearCache() {
    _cache.clear();
  }
}