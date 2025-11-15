import 'dart:io';

import 'uploaded_file.dart'; // whatever your current type is for files

class Request {
  final HttpRequest raw;
  final Map<String, dynamic> params;
  final Map<String, dynamic> query;
  final Map<String, dynamic> body;
  final Map<String, UploadedFile> files;

  Request({
    required this.raw,
    required this.params,
    required this.query,
    required this.body,
    required this.files,
  });

  // --- Common shortcuts ---

  String get method => raw.method;
  Uri get uri => raw.uri;
  HttpHeaders get headers => raw.headers;
  HttpResponse get response => raw.response;

  /// Combines body, query, and params (body wins, then query, then params).
  Map<String, dynamic> all() => {...params, ...query, ...body};

  /// Laravel-style: input("field") → body > query > params
  dynamic input(String key, {dynamic defaultValue}) {
    if (body.containsKey(key)) return body[key];
    if (query.containsKey(key)) return query[key];
    if (params.containsKey(key)) return params[key];
    return defaultValue;
  }

  /// Typed convenience
  String? string(String key) {
    final v = input(key);
    return v?.toString();
  }

  int? intInput(String key) {
    final v = input(key);
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  UploadedFile? file(String key) => files[key];

  // Response helpers so existing patterns still feel nice:
  HttpResponse redirect(String location, {int statusCode = HttpStatus.found}) {
    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.locationHeader, location);
    return response;
  }

  HttpResponse redirectBack() {
    final referer = headers.value('referer') ?? '/';
    return redirect(referer);
  }

  HttpResponse json(Object? data, {int statusCode = HttpStatus.ok}) {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(data); // you can wrap with jsonEncode if needed
    return response;
  }
}
