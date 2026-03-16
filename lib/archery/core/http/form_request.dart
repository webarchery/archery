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
/// Wraps an [HttpRequest] and provides cached access to parsed request input,
/// uploaded files, query parameters, and buffered body data.
///
/// `FormRequest` is responsible for reading the request stream once, buffering
/// it, and parsing supported body formats into convenient field and file
/// accessors.
///
/// Supported body types:
/// - `application/json`
/// - `application/x-www-form-urlencoded`
/// - `multipart/form-data`
///
/// Example:
/// ```dart
/// final form = FormRequest(request);
/// final email = await form.input('email');
/// final avatar = await form.file('avatar');
/// ```
base class FormRequest {
  /// The underlying HTTP request being wrapped.
  final HttpRequest _request;
  /// Parsed body fields extracted from the request body.
  final Map<String, dynamic> _fields;
  /// Uploaded files extracted from multipart form data.
  final Map<String, UploadedFile> _files;
  /// Indicates whether the request body has already been parsed.
  bool _parsed;

  /// Buffered raw request body bytes.
  Uint8List? _bodyBuffer;

  /// Tracks the active parse operation so parsing only happens once.
  Future<void>? _parsingFuture;

  /// Creates a form request wrapper for the given [HttpRequest].
  ///
  /// Parsing is deferred until one of the async accessors is called.
  ///
  /// Example:
  /// ```dart
  /// final form = FormRequest(request);
  /// ```
  FormRequest(this._request)
    : _fields = <String, dynamic>{},
      _files = <String, UploadedFile>{},
      _parsed = false;

  /// Access to the underlying [HttpRequest].
  ///
  /// Example:
  /// ```dart
  /// final rawRequest = form.httpRequest;
  /// print(rawRequest.method);
  /// ```
  HttpRequest get httpRequest => _request;

  /// Returns the value for a single input field.
  ///
  /// Query parameters are checked first, but parsed body fields take precedence
  /// when both sources contain the same key.
  ///
  /// Returns the resolved value or `null` when the key is not present.
  ///
  /// Example:
  /// ```dart
  /// final email = await form.input('email');
  /// final token = await form.input('_token');
  /// ```
  Future<dynamic> input(String key) async {
    await _ensureParsed();

    // Check query parameters first, then body fields
    // Body fields take precedence over query parameters for same key
    final queryValue = _request.uri.queryParameters[key];
    final bodyValue = _fields.containsKey(key) ? _fields[key] : null;

    return bodyValue ?? queryValue;
  }

  /// Returns all parsed input data merged with query parameters.
  ///
  /// Query parameters are included first, then body fields are applied on top,
  /// allowing body values to override matching query keys.
  ///
  /// Example:
  /// ```dart
  /// final values = await form.all();
  /// print(values['email']);
  /// ```
  Future<Map<String, dynamic>> all() async {
    await _ensureParsed();
    return {..._request.uri.queryParameters, ..._fields};
  }

  /// Returns the uploaded file associated with [key].
  ///
  /// This only resolves files parsed from multipart form data.
  ///
  /// Returns the matching [UploadedFile] or `null` when no file exists for the
  /// given field.
  ///
  /// Example:
  /// ```dart
  /// final avatar = await form.file('avatar');
  /// if (avatar != null) {
  ///   print(avatar.filename);
  /// }
  /// ```
  Future<UploadedFile?> file(String key) async {
    await _ensureParsed();
    return _files[key];
  }

  /// Returns all uploaded files parsed from the request.
  ///
  /// The returned map is a copy of the internal file registry.
  ///
  /// Example:
  /// ```dart
  /// final files = await form.files();
  /// print(files.keys);
  /// ```
  Future<Map<String, UploadedFile>> files() async {
    await _ensureParsed();
    return Map<String, UploadedFile>.from(_files);
  }

  /// Returns only the request query parameters.
  ///
  /// This does not trigger body parsing.
  ///
  /// Example:
  /// ```dart
  /// final page = form.query['page'];
  /// ```
  Map<String, String> get query => _request.uri.queryParameters;

  /// Returns only the parsed body fields.
  ///
  /// Query parameters are not included in this result.
  ///
  /// Example:
  /// ```dart
  /// final body = await form.body();
  /// print(body['name']);
  /// ```
  Future<Map<String, dynamic>> body() async {
    await _ensureParsed();
    return Map<String, dynamic>.from(_fields);
  }

  /// Reads the request stream and buffers its bytes in memory.
  ///
  /// This is typically called early to prevent repeated reads of the request
  /// stream and avoid `"Stream already listened"` errors.
  ///
  /// If buffering fails, an empty buffer is stored.
  ///
  /// Example:
  /// ```dart
  /// await form.buffer();
  /// ```
  Future<void> buffer() async {
    if (_bodyBuffer != null) return;

    try {
      final bytes = await _request.fold<BytesBuilder>(
        BytesBuilder(copy: false),
        (builder, chunk) => builder..add(chunk),
      );
      _bodyBuffer = bytes.takeBytes();
    } catch (e) {
      // print("Error buffering request stream: $e");
      _bodyBuffer = Uint8List(0);
    }
  }

  // ----------------------------
  // Parsing Internals
  // ----------------------------

  /// Ensures the request body has been parsed exactly once.
  ///
  /// If parsing has already completed, this returns immediately. If parsing is
  /// in progress, the active parse future is reused.
  ///
  /// Example:
  /// ```dart
  /// await form._ensureParsed();
  /// ```
  Future<void> _ensureParsed() {
    if (_parsed) return Future.value();
    if (_parsingFuture != null) return _parsingFuture!;
    _parsingFuture = _doParse();
    return _parsingFuture!;
  }

  /// Performs buffered body parsing based on the request content type.
  ///
  /// This method:
  /// - ensures the request body is buffered
  /// - determines the request MIME type
  /// - dispatches parsing to the appropriate body parser
  /// - marks the request as parsed even when parsing fails
  ///
  /// Example:
  /// ```dart
  /// await form._doParse();
  /// ```
  Future<void> _doParse() async {
    try {
      // Ensure body is buffered
      await buffer();

      final ct = _request.headers.contentType;
      final mime = ct?.mimeType ?? '';
      final bodyBytes = _bodyBuffer!;

      if (bodyBytes.isEmpty) {
        _parsed = true;
        return;
      }

      if (mime.isEmpty) {
        // print('WARNING: Body is not empty but Content-Type is missing.');
      }

      if (mime == 'application/json') {
        _parseJsonFromBytes(bodyBytes);
      } else if (mime == 'application/x-www-form-urlencoded') {
        _parseFormUrlEncodedFromBytes(bodyBytes);
      } else if (mime == 'multipart/form-data') {
        final boundary = ct?.parameters['boundary'];
        if (boundary != null && boundary.isNotEmpty) {
          await _parseMultipartFormDataFromBytes(bodyBytes, boundary);
        }
      }
    } catch (e) {
      // print('Error parsing request body: $e');
    } finally {
      _parsed = true;
    }
  }

  /// Parses a JSON request body into [_fields].
  ///
  /// Only top-level JSON objects are merged into the field map.
  ///
  /// Example:
  /// ```dart
  /// form._parseJsonFromBytes(
  ///   Uint8List.fromList(utf8.encode('{"email":"jane@example.com"}')),
  /// );
  /// ```
  void _parseJsonFromBytes(Uint8List bodyBytes) {
    try {
      final body = utf8.decode(bodyBytes);
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          _fields.addAll(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e) {
      // print('JSON parsing failed: $e');
    }
  }

  /// Parses a URL-encoded form body into [_fields].
  ///
  /// Example:
  /// ```dart
  /// form._parseFormUrlEncodedFromBytes(
  ///   Uint8List.fromList(utf8.encode('name=Jane&email=jane@example.com')),
  /// );
  /// ```
  void _parseFormUrlEncodedFromBytes(Uint8List bodyBytes) {
    final body = utf8.decode(bodyBytes);
    if (body.isNotEmpty) {
      _fields.addAll(Uri.splitQueryString(body));
    }
  }

  /// Parses multipart form data into [_fields] and [_files].
  ///
  /// Regular form inputs are stored in [_fields]. File parts are converted into
  /// [UploadedFile] instances and stored in [_files].
  ///
  /// Empty file inputs are represented with [UploadedFile.empty].
  ///
  /// Example:
  /// ```dart
  /// await form._parseMultipartFormDataFromBytes(bodyBytes, boundary);
  /// ```
  Future<void> _parseMultipartFormDataFromBytes(
    Uint8List bodyBytes,
    String boundary,
  ) async {
    final stream = Stream<Uint8List>.value(bodyBytes);
    final transformer = MimeMultipartTransformer(boundary);
    final partsStream = transformer.bind(stream);

    await for (final part in partsStream) {
      // print('DB_LOG: Found part. Headers: ${part.headers}');
      // Handle case-insensitive headers
      final dispositionKey = part.headers.keys.firstWhere(
        (k) => k.toLowerCase() == 'content-disposition',
        orElse: () => '',
      );

      if (dispositionKey.isEmpty) {
        // print('DB_LOG: No content-disposition found');
        continue;
      }

      final contentDisposition = part.headers[dispositionKey];
      // print('DB_LOG: Disposition value: $contentDisposition');

      if (contentDisposition == null) continue;

      final params = _parseContentDisposition(contentDisposition);
      final name = params['name'];
      // print('DB_LOG: Extracted name: $name');

      if (name == null) continue;

      final filename = params['filename'];

      if (filename != null && filename.isNotEmpty) {
        // File upload
        final chunks = <List<int>>[];
        await for (final chunk in part) {
          chunks.add(chunk);
        }
        final bytes = Uint8List.fromList(chunks.expand((x) => x).toList());

        if (bytes.isNotEmpty) {
          _files[name] = UploadedFile.fromBytes(
            filename: filename,
            bytes: bytes,
            contentType:
                part.headers['content-type'] ?? 'application/octet-stream',
          );
        } else {
          _files[name] = UploadedFile.empty();
        }
      } else if (filename != null && filename.isEmpty) {
        // Empty file field
        _files[name] = UploadedFile.empty();
      } else {
        // Regular form field
        final value = await utf8.decoder.bind(part).join();
        // print('DB_LOG: Regular field value for $name: $value');
        _fields[name] = value;
      }
    }
  }

  /// Parses a `Content-Disposition` header into key/value parameters.
  ///
  /// Common extracted values include `name` and `filename`.
  ///
  /// Example:
  /// ```dart
  /// final params = form._parseContentDisposition(
  ///   'form-data; name="avatar"; filename="me.png"',
  /// );
  ///
  /// print(params['name']); // avatar
  /// print(params['filename']); // me.png
  /// ```
  Map<String, String> _parseContentDisposition(String contentDisposition) {
    final params = <String, String>{};
    final parts = contentDisposition.split(';');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('=')) {
        final keyValue = trimmed.split('=');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          var value = keyValue[1].trim();
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          }
          params[key] = value;
        }
      }
    }
    return params;
  }
}
