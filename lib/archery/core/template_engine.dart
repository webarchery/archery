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

/// An error raised while locating, parsing, or rendering a template.
base class TemplateEngineException implements Exception {
  /// A human-readable description of the template error.
  String? message;

  /// Creates a template exception with [message].
  TemplateEngineException(this.message);

  /// Creates an exception for a variable that cannot be resolved.
  TemplateEngineException.variableNotFound(String? m) : message = m;

  /// Creates an exception for a template file that cannot be found.
  TemplateEngineException.templateNotFound(String? m) : message = m;

  /// Creates an exception for invalid template or expression syntax.
  TemplateEngineException.parseError(String? m) : message = m;

  @override
  String toString() => "Template Error: $message";
}

/// Base type for expressions embedded in template output and directives.
abstract class Expr {}

/// An expression containing a constant string, number, boolean, or null value.
class LiteralExpr extends Expr {
  /// The constant value represented by this expression.
  final dynamic value;

  /// Creates a literal expression containing [value].
  LiteralExpr(this.value);
}

/// A reference to a value in the render context.
///
/// Dotted references such as `user.profile.name` are stored as individual
/// path segments and resolved during rendering.
class VariableExpr extends Expr {
  /// The ordered segments of the dotted variable path.
  final List<String> path;

  /// Creates a variable reference from [path].
  VariableExpr(this.path);
}

/// A logical negation expression, such as `!user.isActive`.
class UnaryNotExpr extends Expr {
  /// The expression whose truthiness is negated.
  final Expr operand;

  /// Creates a logical negation of [operand].
  UnaryNotExpr(this.operand);
}

/// An expression that applies a binary operator to two operands.
class BinaryExpr extends Expr {
  /// The expression evaluated on the left of [op].
  final Expr left;

  /// The arithmetic, equality, or comparison operator.
  ///
  /// Supported values are `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `<=`, `>`,
  /// and `>=`.
  final String op;

  /// The expression evaluated on the right of [op].
  final Expr right;

  /// Creates a binary expression from [left], [op], and [right].
  BinaryExpr(this.left, this.op, this.right);
}

enum _ExprTokenType { number, string, ident, op, lparen, rparen, eof }

class _ExprToken {
  final _ExprTokenType type;
  final dynamic value;
  _ExprToken(this.type, this.value);
}

List<_ExprToken> _lexExpr(String src) {
  final tokens = <_ExprToken>[];
  int i = 0;
  bool isIdentStart(String c) => RegExp(r'[a-zA-Z_]').hasMatch(c);
  bool isIdentPart(String c) => RegExp(r'[a-zA-Z0-9_]').hasMatch(c);

  while (i < src.length) {
    final c = src[i];

    if (c == ' ' || c == '\t' || c == '\n') {
      i++;
      continue;
    }

    if (c == "'" || c == '"') {
      final quote = c;
      final sb = StringBuffer();
      i++;
      while (i < src.length && src[i] != quote) {
        sb.write(src[i]);
        i++;
      }
      i++;
      tokens.add(_ExprToken(_ExprTokenType.string, sb.toString()));
      continue;
    }

    if (RegExp(r'[0-9]').hasMatch(c)) {
      final start = i;
      while (i < src.length && RegExp(r'[0-9.]').hasMatch(src[i])) {
        i++;
      }
      final text = src.substring(start, i);
      tokens.add(_ExprToken(_ExprTokenType.number, num.parse(text)));
      continue;
    }

    if (isIdentStart(c)) {
      final sb = StringBuffer();
      while (i < src.length && isIdentPart(src[i])) {
        sb.write(src[i]);
        i++;
      }
      while (i < src.length &&
          src[i] == '.' &&
          i + 1 < src.length &&
          isIdentStart(src[i + 1])) {
        sb.write('.');
        i++;
        while (i < src.length && isIdentPart(src[i])) {
          sb.write(src[i]);
          i++;
        }
      }
      if (i + 1 < src.length && src[i] == '(' && src[i + 1] == ')') {
        i += 2;
      }
      tokens.add(_ExprToken(_ExprTokenType.ident, sb.toString()));
      continue;
    }

    if (i + 1 < src.length) {
      final two = src.substring(i, i + 2);
      if (['==', '!=', '<=', '>='].contains(two)) {
        tokens.add(_ExprToken(_ExprTokenType.op, two));
        i += 2;
        continue;
      }
    }

    if (c == '(') {
      tokens.add(_ExprToken(_ExprTokenType.lparen, c));
      i++;
      continue;
    }
    if (c == ')') {
      tokens.add(_ExprToken(_ExprTokenType.rparen, c));
      i++;
      continue;
    }
    if ('+-*/<>!'.contains(c)) {
      tokens.add(_ExprToken(_ExprTokenType.op, c));
      i++;
      continue;
    }

    throw TemplateEngineException.parseError(
      "Unexpected character '$c' in expression: $src",
    );
  }

  tokens.add(_ExprToken(_ExprTokenType.eof, null));
  return tokens;
}

/// Parses the expression language used inside template tags and directives.
///
/// Operators follow conventional precedence: unary negation, multiplication
/// and division, addition and subtraction, comparisons, then equality.
class ExprParser {
  final List<_ExprToken> _tokens;
  int _pos = 0;

  /// Creates a parser and tokenizes [source].
  ExprParser(String source) : _tokens = _lexExpr(source);

  _ExprToken get _cur => _tokens[_pos];

  /// Parses [source] and returns its expression tree.
  ///
  /// Throws [TemplateEngineException] when the expression is malformed.
  Expr parse() {
    final e = _equality();
    return e;
  }

  Expr _equality() {
    var left = _comparison();
    while (_cur.type == _ExprTokenType.op &&
        (_cur.value == '==' || _cur.value == '!=')) {
      final op = _cur.value as String;
      _pos++;
      left = BinaryExpr(left, op, _comparison());
    }
    return left;
  }

  Expr _comparison() {
    var left = _additive();
    while (_cur.type == _ExprTokenType.op &&
        ['<', '<=', '>', '>='].contains(_cur.value)) {
      final op = _cur.value as String;
      _pos++;
      left = BinaryExpr(left, op, _additive());
    }
    return left;
  }

  Expr _additive() {
    var left = _multiplicative();
    while (_cur.type == _ExprTokenType.op &&
        (_cur.value == '+' || _cur.value == '-')) {
      final op = _cur.value as String;
      _pos++;
      left = BinaryExpr(left, op, _multiplicative());
    }
    return left;
  }

  Expr _multiplicative() {
    var left = _unary();
    while (_cur.type == _ExprTokenType.op &&
        (_cur.value == '*' || _cur.value == '/')) {
      final op = _cur.value as String;
      _pos++;
      left = BinaryExpr(left, op, _unary());
    }
    return left;
  }

  Expr _unary() {
    if (_cur.type == _ExprTokenType.op && _cur.value == '!') {
      _pos++;
      return UnaryNotExpr(_unary());
    }
    return _primary();
  }

  Expr _primary() {
    final t = _cur;
    switch (t.type) {
      case _ExprTokenType.number:
        _pos++;
        return LiteralExpr(t.value);
      case _ExprTokenType.string:
        _pos++;
        return LiteralExpr(t.value);
      case _ExprTokenType.ident:
        _pos++;
        if (t.value == 'true') return LiteralExpr(true);
        if (t.value == 'false') return LiteralExpr(false);
        if (t.value == 'null') return LiteralExpr(null);
        return VariableExpr((t.value as String).split('.'));
      case _ExprTokenType.lparen:
        _pos++;
        final inner = _equality();
        if (_cur.type != _ExprTokenType.rparen) {
          throw TemplateEngineException.parseError('Expected ) in expression');
        }
        _pos++;
        return inner;
      default:
      // Empty expression, e.g. {{ }} — treat as empty string literal.
        return LiteralExpr('');
    }
  }
}

/// Base type for nodes in a parsed template.
abstract class Node {}

/// A literal block of template text.
class TextNode extends Node {
  /// The text emitted exactly as it appears in the template.
  final String text;

  /// Creates a text node containing [text].
  TextNode(this.text);
}

/// An expression whose result is written to the rendered output.
class OutputNode extends Node {
  /// The expression evaluated when this node is rendered.
  final Expr expression;

  /// Whether HTML-sensitive characters in the result are escaped.
  final bool escaped;

  /// Creates an output node for [expression].
  OutputNode(this.expression, this.escaped);
}

/// A conditional block created from an `@if` directive.
class IfNode extends Node {
  /// The expression used to select a branch.
  final Expr condition;

  /// Nodes rendered when [condition] is truthy.
  final List<Node> thenBranch;

  /// Nodes rendered when [condition] is falsey.
  final List<Node> elseBranch;

  /// Creates a conditional node with its two possible branches.
  IfNode(this.condition, this.thenBranch, this.elseBranch);
}

/// A loop created from an `@foreach(item in collection)` directive.
class ForeachNode extends Node {
  /// The context variable assigned to each collection element.
  final String itemName;

  /// The expression that resolves to the collection being iterated.
  final Expr collection;

  /// The nodes rendered once for each collection element.
  final List<Node> body;

  /// Creates a loop over [collection], binding each value to [itemName].
  ForeachNode(this.itemName, this.collection, this.body);
}

/// A named content block supplied to a layout.
class SectionNode extends Node {
  /// The name used to match this section to a [YieldNode].
  final String name;

  /// The content belonging to this section.
  final List<Node> body;

  /// Creates a section named [name].
  SectionNode(this.name, this.body);
}

/// A layout placeholder populated by a matching [SectionNode].
class YieldNode extends Node {
  /// The name of the section to render at this location.
  final String name;

  /// Creates a placeholder for the section called [name].
  YieldNode(this.name);
}

/// A reference to another template that should be rendered inline.
class IncludeNode extends Node {
  /// The dot-delimited name of the included template.
  final String templateName;

  /// Optional raw data text supplied after the template name.
  ///
  /// The parser preserves this value for future evaluation; the current
  /// renderer passes the existing render context to included templates.
  final String? dataJson;

  /// Creates an include node for [templateName].
  IncludeNode(this.templateName, this.dataJson);
}

/// A directive that emits a hidden CSRF-token input.
class CsrfNode extends Node {}

/// The root of a parsed template.
class TemplateNode {
  /// Top-level nodes in source order.
  final List<Node> children;

  /// Optional dot-delimited layout name declared by `@layout`.
  final String? layoutName;

  /// Creates a template root with [children] and an optional [layoutName].
  TemplateNode(this.children, this.layoutName);
}

// --- Template tokenizer ----------------------------------------------------

enum _TokenType { text, output, directive, eof }

class _Token {
  final _TokenType type;
  final String? text;
  final bool escaped;
  final String? name;
  final String? args;
  _Token.text(this.text)
      : type = _TokenType.text,
        escaped = false,
        name = null,
        args = null;

  _Token.output(this.text, this.escaped)
      : type = _TokenType.output,
        name = null,
        args = null;

  _Token.directive(this.name, this.args)
      : type = _TokenType.directive,
        text = null,
        escaped = false;

  _Token.eof()
      : type = _TokenType.eof,
        text = null,
        escaped = false,
        name = null,
        args = null;
}

const _directiveNames =
    'if|else|endif|foreach|endforeach|section|endsection|yield|include|csrf|layout|unless|endunless';
final RegExp _tokenPattern = RegExp(
  r'\{!!\s*(.*?)\s*!!\}'
  r'|\{\{\s*(.*?)\s*\}\}'
  r'|@@'
  '|@($_directiveNames)(?!\\w)(\\((?:[^()]|\\([^()]*\\))*\\))?',
  dotAll: true,
);

List<_Token> _tokenizeTemplate(String source) {
  final tokens = <_Token>[];
  int pos = 0;

  for (final m in _tokenPattern.allMatches(source)) {
    if (m.start > pos) {
      tokens.add(_Token.text(source.substring(pos, m.start)));
    }
    if (m.group(1) != null) {
      tokens.add(_Token.output(m.group(1)!, false));
    } else if (m.group(2) != null) {
      tokens.add(_Token.output(m.group(2)!, true));
    } else if (m.group(3) != null) {
      final raw = m.group(4);
      final args = raw?.substring(1, raw.length - 1).trim();
      tokens.add(_Token.directive(m.group(3)!, args));
    }
    pos = m.end;
  }
  if (pos < source.length) {
    tokens.add(_Token.text(source.substring(pos)));
  }
  tokens.add(_Token.eof());
  return tokens;
}

String _stripQuotes(String s) {
  s = s.trim();
  if (s.length >= 2 &&
      ((s.startsWith("'") && s.endsWith("'")) ||
          (s.startsWith('"') && s.endsWith('"')))) {
    return s.substring(1, s.length - 1);
  }
  return s;
}

/// Converts template source into a [TemplateNode] syntax tree.
///
/// The parser recognizes escaped (`{{ ... }}`) and raw (`{!! ... !!}`)
/// output, plus layout, section, yield, include, CSRF, conditional, and loop
/// directives.
class TemplateParser {
  final List<_Token> _tokens;
  int _position = 0;

  /// Creates a parser and tokenizes [source].
  TemplateParser(String source) : _tokens = _tokenizeTemplate(source);

  _Token get _current => _tokens[_position];

  /// Parses the complete source and returns its template tree.
  ///
  /// A leading `@layout` directive is recorded in [TemplateNode.layoutName].
  TemplateNode parseTemplate() {
    String? layoutName;
    if (_current.type == _TokenType.directive && _current.name == 'layout') {
      layoutName = _stripQuotes(_current.args ?? '');
      _position++;
    }
    final children = parseNodes(stopAt: const {});
    return TemplateNode(children, layoutName);
  }

  /// Parses nodes until end-of-file or a directive named in [stopAt].
  ///
  /// Stop directives are not consumed, allowing the enclosing directive
  /// parser to handle them.
  List<Node> parseNodes({required Set<String> stopAt}) {
    final nodes = <Node>[];
    while (_current.type != _TokenType.eof) {
      if (_current.type == _TokenType.directive &&
          stopAt.contains(_current.name)) {
        break;
      }
      nodes.add(_parseNode());
    }
    return nodes;
  }

  Node _parseNode() {
    final token = _current;
    switch (token.type) {
      case _TokenType.text:
        _position++;
        return TextNode(token.text!);
      case _TokenType.output:
        _position++;
        return OutputNode(ExprParser(token.text!).parse(), token.escaped);
      case _TokenType.directive:
        return _parseDirective();
      case _TokenType.eof:
        throw TemplateEngineException.parseError('Unexpected end of template');
    }
  }

  Node _parseDirective() {
    switch (_current.name) {
      case 'if':
        return _parseIf();
      case 'foreach':
        return _parseForeach();
      case 'section':
        return _parseSection();
      case 'include':
        return _parseInclude();
      case 'yield':
        final name = _stripQuotes(_current.args ?? '');
        _position++;
        return YieldNode(name);
      case 'csrf':
        _position++;
        return CsrfNode();
      default:
        throw TemplateEngineException.parseError(
          'Unexpected @${_current.name}',
        );
    }
  }

  void _expect(String name) {
    if (_current.type != _TokenType.directive || _current.name != name) {
      throw TemplateEngineException.parseError('Expected @$name');
    }
    _position++;
  }

  Node _parseIf() {
    final condition = ExprParser(_current.args ?? '').parse();
    _position++;
    final thenBranch = parseNodes(stopAt: {'else', 'endif'});
    List<Node> elseBranch = [];
    if (_current.type == _TokenType.directive && _current.name == 'else') {
      _position++;
      elseBranch = parseNodes(stopAt: {'endif'});
    }
    _expect('endif');
    return IfNode(condition, thenBranch, elseBranch);
  }

  Node _parseForeach() {
    final args = _current.args ?? '';
    _position++;
    final parts = args.split(' in ').map((s) => s.trim()).toList();
    if (parts.length != 2) {
      throw TemplateEngineException.parseError('Malformed @foreach($args)');
    }
    final body = parseNodes(stopAt: {'endforeach'});
    _expect('endforeach');
    return ForeachNode(parts[0], ExprParser(parts[1]).parse(), body);
  }

  Node _parseSection() {
    final name = _stripQuotes(_current.args ?? '');
    _position++;
    final body = parseNodes(stopAt: {'endsection'});
    _expect('endsection');
    return SectionNode(name, body);
  }

  Node _parseInclude() {
    final args = _current.args ?? '';
    _position++;
    final trimmed = args.trim();
    final quote = trimmed.startsWith('"') ? '"' : "'";
    final closeIdx = trimmed.indexOf(quote, 1);
    if (!trimmed.startsWith(quote) || closeIdx == -1) {
      throw TemplateEngineException.parseError('Malformed @include($args)');
    }
    final name = trimmed.substring(1, closeIdx);
    var rest = trimmed.substring(closeIdx + 1).trim();
    if (rest.startsWith(',')) rest = rest.substring(1).trim();
    return IncludeNode(name, rest.isEmpty ? null : rest);
  }
}

/// Parses and renders Archery HTML templates.
///
/// Templates are loaded from [viewsDirectory] by converting dot-delimited
/// names to paths and appending `.html`. For example, `users.profile` resolves
/// to `users/profile.html`. Parsed syntax trees are cached when [shouldCache]
/// is true.
base class TemplateEngine {
  /// Directory containing template files.
  final String viewsDirectory;

  /// Directory containing publicly served assets.
  final String publicDirectory;

  final Map<String, TemplateNode> _astCache = {};

  /// Whether parsed file templates are retained between render calls.
  bool shouldCache = true;

  /// Creates a template engine using the given view and public directories.
  TemplateEngine({required this.viewsDirectory, required this.publicDirectory});

  /// Loads and renders the template identified by [templateName].
  ///
  /// Values in [data] are available to expressions by key. Throws
  /// [TemplateEngineException] if the template cannot be found or parsed.
  Future<String> render(
      String templateName, [
        Map<String, dynamic>? data,
      ]) async {
    final ast = await _loadAst(templateName);
    return _renderTemplate(ast, data ?? {});
  }

  /// Parses and renders template [source] without using the AST cache.
  Future<String> renderString(
      String source, [
        Map<String, dynamic>? data,
      ]) async {
    final ast = TemplateParser(source).parseTemplate();
    return _renderTemplate(ast, data ?? {});
  }

  Future<TemplateNode> _loadAst(String templateName) async {
    if (shouldCache && _astCache.containsKey(templateName)) {
      return _astCache[templateName]!;
    }

    final templatePath =
        '${viewsDirectory.replaceAll(RegExp(r'/+$'), '')}/'
        '${templateName.replaceAll('.', '/')}.html';
    final file = File(templatePath);
    if (!await file.exists()) {
      throw TemplateEngineException.templateNotFound(
        "HTML view for '$templateName' was not found at path: $templatePath",
      );
    }

    final source = await file.readAsString();
    final ast = TemplateParser(source).parseTemplate();
    if (shouldCache) _astCache[templateName] = ast;

    return ast;
  }

  Future<String> _renderTemplate(
      TemplateNode ast,
      Map<String, dynamic> data,
      ) async {
    if (ast.layoutName != null) {
      final sections = <String, List<Node>>{
        for (final n in ast.children)
          if (n is SectionNode) n.name: n.body,
      };
      final layoutAst = await _loadAst(ast.layoutName!);
      return _renderNodes(layoutAst.children, data, sections);
    }
    return _renderNodes(ast.children, data, const {});
  }

  Future<String> _renderNodes(
      List<Node> nodes,
      Map<String, dynamic> data,
      Map<String, List<Node>> sections,
      ) async {
    final buffer = StringBuffer();
    for (final node in nodes) {
      buffer.write(await _renderNode(node, data, sections));
    }
    return buffer.toString();
  }

  Future<String> _renderNode(
      Node node,
      Map<String, dynamic> data,
      Map<String, List<Node>> sections,
      ) async {
    switch (node) {
      case TextNode n:
        return n.text;

      case OutputNode n:
        final value = _evaluate(n.expression, data);
        final str = value?.toString() ?? '';
        return n.escaped ? _escapeHtml(str) : str;

      case IfNode n:
        final branch = _truthy(_evaluate(n.condition, data))
            ? n.thenBranch
            : n.elseBranch;
        return _renderNodes(branch, data, sections);

      case ForeachNode n:
        final collection = _evaluate(n.collection, data);
        if (collection is! List) return '';
        final buf = StringBuffer();
        for (final item in collection) {
          final loopData = Map<String, dynamic>.from(data)..[n.itemName] = item;
          buf.write(await _renderNodes(n.body, loopData, sections));
        }
        return buf.toString();

      case SectionNode n:
        return _renderNodes(n.body, data, sections);

      case YieldNode n:
        final body = sections[n.name];
        if (body == null) return '';
        return _renderNodes(body, data, sections);

      case IncludeNode n:
        final includedAst = await _loadAst(n.templateName);

        return _renderTemplate(includedAst, data);

      case CsrfNode _:
        final token = data['csrf_token']?.toString() ?? '';
        return '<input type="hidden" name="_token" value="$token">';

      default:
        return '';
    }
  }

  dynamic _evaluate(Expr expr, Map<String, dynamic> data) {
    switch (expr) {
      case LiteralExpr e:
        return e.value;
      case VariableExpr e:
        return _resolvePath(e.path, data);
      case UnaryNotExpr e:
        return !_truthy(_evaluate(e.operand, data));
      case BinaryExpr e:
        final l = _evaluate(e.left, data);
        final r = _evaluate(e.right, data);
        return _applyOp(e.op, l, r);
      default:
        return null;
    }
  }

  dynamic _applyOp(String op, dynamic l, dynamic r) {
    switch (op) {
      case '+':
        if (l is num && r is num) return l + r;
        return '${l ?? ''}${r ?? ''}';
      case '-':
        return (l as num) - (r as num);
      case '*':
        return (l as num) * (r as num);
      case '/':
        return (l as num) / (r as num);
      case '==':
        return l == r;
      case '!=':
        return l != r;
      case '<':
        return (l as num) < (r as num);
      case '<=':
        return (l as num) <= (r as num);
      case '>':
        return (l as num) > (r as num);
      case '>=':
        return (l as num) >= (r as num);
      default:
        throw TemplateEngineException('Unknown operator $op');
    }
  }

  bool _truthy(dynamic v) => v != null && v != false && v != '' && v != 0;

  dynamic _resolvePath(List<String> path, Map<String, dynamic> data) {
    dynamic current = data;
    for (final part in path) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(part)) return '';
        current = current[part];
      } else if (current is List) {
        final idx = int.tryParse(part);
        if (idx != null) {
          current = idx < current.length ? current[idx] : '';
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
        if (part == 'length') return current.length;
        if (part == 'isEmpty') return current.isEmpty;
        if (part == 'isNotEmpty') return current.isNotEmpty;
        return '';
      } else if (current == null) {
        return '';
      } else {
        return '';
      }
    }
    return current ?? '';
  }

  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#x27;')
      .replaceAll('/', '&#x2F;');

  /// Removes all parsed templates from the in-memory AST cache.
  void clearCache() => _astCache.clear();
}
